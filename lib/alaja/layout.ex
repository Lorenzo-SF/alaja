defmodule Alaja.Layout do
  @moduledoc """
  Flexbox-style layout engine for the TUI runtime.

  Walks a View.Node tree, measures it against constraints, then arranges
  each node into a fixed rectangle. The result is a Frame.

  ## Supported nodes

    * `:column` — flex-direction column, distributes free space to children
      with `flex: n`. Supports `gap`, `padding`, `align`.
    * `:row` — flex-direction row, same options as column.
    * `:grid` — fixed-grid layout with `:columns` count.
    * `:text` — single-line text (wraps soft if `:wrap` is true).
    * `:box` — wraps a child with border + padding.
    * `:rule` — horizontal line using `─`.
    * `:status_bar` — text anchored to the bottom row of the frame.

  ## Props (all optional unless noted)

    * `:flex` — non-negative integer (default 0).
    * `:width` — `:fill | pos_integer | :auto` (default `:auto`).
    * `:height` — `:fill | pos_integer | :auto`.
    * `:align` — `:start | :center | :end` (default `:start`).
    * `:padding` — non-negative integer (per side).
    * `:gap` — non-negative integer (between children).
    * `:border` — `:none | :single | :rounded | :heavy | :double`.
    * `:wrap` — boolean (for text).
    * `:content` — required for `:text` and `:status_bar`.
    * `:columns` — required for `:grid`.

  Children whose combined measure exceeds the constraint are clipped
  (rendered up to the constraint; extra cells are dropped).

  ## Examples

      Alaja.Layout.measure(
        Alaja.View.column([
          Alaja.View.text("hello"),
          Alaja.View.row([Alaja.View.text("a"), Alaja.View.text("b")])
        ]),
        %{width: 10, height: 5}
      )
      # => %{width: 5, height: 3}

      Alaja.Layout.arrange(node, %{width: 80, height: 24})
      # => [%{node: child, x: 1, y: 1, w: 80, h: 1}, ...]
  """

  alias Alaja.{Frame, View.Node}

  @type constraints :: %{width: pos_integer(), height: pos_integer()}

  @doc """
  Measures a node: returns the natural `{width, height}` of the tree.
  """
  @spec measure(Node.t(), constraints()) :: {non_neg_integer(), non_neg_integer()}
  def measure(%Node{tag: :text, props: props}, _constraints) do
    content = Keyword.get(props, :content, "")
    {String.length(content), 1}
  end

  def measure(%Node{tag: :rule}, _constraints), do: {1, 1}

  def measure(%Node{tag: :status_bar, props: props}, _constraints),
    do: {String.length(Keyword.get(props, :content, "")), 1}

  def measure(%Node{tag: :box, children: [child | _], props: props}, constraints) do
    {cw, ch} = measure(child, constraints)
    pad = Keyword.get(props, :padding, 0)
    border = Keyword.get(props, :border, :none)
    border_w = if border == :none, do: 0, else: 2
    {cw + 2 * pad + border_w, ch + 2 * pad + border_w}
  end

  def measure(%Node{tag: :column, children: children, props: props}, constraints) do
    gap = Keyword.get(props, :gap, 0)
    pad = Keyword.get(props, :padding, 0)

    {w, h} =
      children
      |> Enum.map(fn c -> measure(c, constraints) end)
      |> Enum.reduce({0, 0}, fn {cw, ch}, {mw, mh} ->
        {max(mw, cw), mh + ch}
      end)

    {w + 2 * pad, h + (length(children) - 1) * gap + 2 * pad}
  end

  def measure(%Node{tag: :row, children: children, props: props}, constraints) do
    gap = Keyword.get(props, :gap, 0)
    pad = Keyword.get(props, :padding, 0)

    {w, h} =
      children
      |> Enum.map(fn c -> measure(c, constraints) end)
      |> Enum.reduce({0, 0}, fn {cw, ch}, {mw, mh} ->
        {mw + cw, max(mh, ch)}
      end)

    {w + (length(children) - 1) * gap + 2 * pad, h + 2 * pad}
  end

  def measure(%Node{tag: :grid, children: children, props: props}, constraints) do
    cols = max(Keyword.get(props, :columns, 1), 1)
    gap = Keyword.get(props, :gap, 0)
    pad = Keyword.get(props, :padding, 0)
    rows = ceil(length(children) / cols)

    child_measurements =
      Enum.map(children, fn c -> measure(c, constraints) end)

    # chunk into rows of `cols` to measure per-row width/height
    {cw, rh} =
      child_measurements
      |> Enum.chunk_every(cols)
      |> Enum.reduce({0, 0}, fn row, {mw, mh} ->
        row_w = Enum.reduce(row, 0, fn {w, _}, acc -> acc + w end)
        row_h = Enum.reduce(row, 0, fn {_, h}, acc -> max(acc, h) end)
        {max(mw, row_w), max(mh, row_h)}
      end)

    # cw = max row width (cells in a row stack horizontally, so add their widths)
    # rh = max row height (cells in a row align vertically)
    {cw + (cols - 1) * gap + 2 * pad, rh * rows + (rows - 1) * gap + 2 * pad}
  end

  def measure(_, _), do: {0, 0}

  @doc """
  Arranges a node tree into a list of placements
  `[%{node: Node.t(), x, y, w, h}]`.

  Placements are returned bottom-up so callers can walk in render order.
  """
  @spec arrange(Node.t(), constraints()) :: [
          %{
            node: Node.t(),
            x: pos_integer(),
            y: pos_integer(),
            w: pos_integer(),
            h: pos_integer()
          }
        ]
  def arrange(node, constraints) do
    do_arrange(node, 1, 1, constraints.width, constraints.height, :start, constraints.height)
  end

  # do_arrange(node, x, y, w, h, align, frame_h)
  # frame_h is the height of the root frame, used by status_bar to anchor to bottom.
  defp do_arrange(%Node{tag: :text, props: props} = node, x, y, w, _h, _align, _frame_h) do
    content = Keyword.get(props, :content, "")
    width = min(String.length(content), w)
    [%{node: node, x: x, y: y, w: max(width, 0), h: 1}]
  end

  defp do_arrange(%Node{tag: :rule} = node, x, y, w, _h, _align, _frame_h) do
    [%{node: node, x: x, y: y, w: max(w, 0), h: 1}]
  end

  defp do_arrange(%Node{tag: :status_bar, props: props} = node, x, _y, _w, _h, _align, frame_h) do
    content = Keyword.get(props, :content, "")
    # status_bar anchors to the bottom row of the root frame
    [%{node: node, x: x, y: frame_h, w: String.length(content), h: 1}]
  end

  defp do_arrange(
         %Node{tag: :box, children: [child | _], props: props} = node,
         x,
         y,
         w,
         h,
         align,
         frame_h
       ) do
    border = Keyword.get(props, :border, :none)
    pad = Keyword.get(props, :padding, 0)

    inner_w =
      if border == :none,
        do: max(w - 2 * pad, 0),
        else: max(w - 2 - 2 * pad, 0)

    inner_h =
      if border == :none,
        do: max(h - 2 * pad, 0),
        else: max(h - 2 - 2 * pad, 0)

    inner_x = if border == :none, do: x + pad, else: x + 1 + pad
    inner_y = if border == :none, do: y + pad, else: y + 1 + pad

    child_placements = do_arrange(child, inner_x, inner_y, inner_w, inner_h, align, frame_h)

    # Add a synthetic placement for the box border itself
    [%{node: node, x: x, y: y, w: max(w, 0), h: max(h, 0)} | child_placements]
  end

  defp do_arrange(%Node{tag: :box}, x, y, w, h, _align, _frame_h) do
    [%{node: %Node{tag: :box}, x: x, y: y, w: max(w, 0), h: max(h, 0)}]
  end

  defp do_arrange(
         %Node{tag: :column, children: children, props: props} = _node,
         x,
         y,
         w,
         h,
         align,
         frame_h
       ) do
    gap = Keyword.get(props, :gap, 0)
    pad = Keyword.get(props, :padding, 0)
    avail_h = max(h - 2 * pad, 0)
    inner_x = x + pad
    inner_y = y + pad

    # If we have a status_bar child, reserve the last row for it
    sb_idx = status_bar_index(children)

    {sb_reserved, non_sb_children} =
      if sb_idx do
        {1, List.delete_at(children, sb_idx)}
      else
        {0, children}
      end

    non_sb_avail_h = max(avail_h - sb_reserved, 0)
    sizes = Enum.map(non_sb_children, fn c -> measure(c, %{width: w, height: non_sb_avail_h}) end)
    total = Enum.sum(Enum.map(sizes, &elem(&1, 1)))
    n = max(length(non_sb_children) - 1, 0)
    free = max(non_sb_avail_h - total - n * gap, 0)

    flexes =
      Enum.map(non_sb_children, fn c -> Keyword.get(c.props, :flex, 0) end)

    flex_total = Enum.sum(flexes)

    heights =
      if flex_total > 0 do
        Enum.zip(sizes, flexes)
        |> Enum.map(fn
          {{_, sh}, 0} -> sh
          {{_, sh}, f} -> sh + div(f * free, flex_total)
        end)
      else
        Enum.map(sizes, &elem(&1, 1))
      end

    {placements, _} =
      non_sb_children
      |> Enum.zip(heights)
      |> Enum.reduce({[], inner_y}, fn {child, ch}, {acc, cy} ->
        child_placements = do_arrange(child, inner_x, cy, max(w - 2 * pad, 0), ch, align, frame_h)
        new_acc = acc ++ child_placements
        {new_acc, cy + ch + gap}
      end)

    # Place the status_bar at the bottom row, full width
    sb_placements =
      if sb_idx do
        sb_child = Enum.at(children, sb_idx)
        sb_w = max(w, 0)
        [%{node: sb_child, x: inner_x, y: frame_h, w: sb_w, h: 1}]
      else
        []
      end

    sb_placements ++ placements
  end

  defp do_arrange(
         %Node{tag: :row, children: children, props: props} = _node,
         x,
         y,
         w,
         h,
         align,
         frame_h
       ) do
    gap = Keyword.get(props, :gap, 0)
    pad = Keyword.get(props, :padding, 0)
    avail_w = max(w - 2 * pad, 0)
    inner_x = x + pad
    inner_y = y + pad

    sizes = Enum.map(children, fn c -> measure(c, %{width: avail_w, height: h}) end)
    total = Enum.sum(Enum.map(sizes, &elem(&1, 0)))
    n = max(length(children) - 1, 0)
    free = max(avail_w - total - n * gap, 0)

    flexes = Enum.map(children, fn c -> Keyword.get(c.props, :flex, 0) end)
    flex_total = Enum.sum(flexes)

    widths =
      if flex_total > 0 do
        Enum.zip(sizes, flexes)
        |> Enum.map(fn
          {{sw, _}, 0} -> sw
          {{sw, _}, f} -> sw + div(f * free, flex_total)
        end)
      else
        Enum.map(sizes, &elem(&1, 0))
      end

    {placements, _} =
      children
      |> Enum.zip(widths)
      |> Enum.reduce({[], inner_x}, fn {child, cw}, {acc, cx} ->
        child_placements = do_arrange(child, cx, inner_y, cw, max(h - 2 * pad, 0), align, frame_h)
        new_acc = acc ++ child_placements
        {new_acc, cx + cw + gap}
      end)

    placements
  end

  defp do_arrange(
         %Node{tag: :grid, children: children, props: props} = _node,
         x,
         y,
         w,
         h,
         align,
         frame_h
       ) do
    cols = max(Keyword.get(props, :columns, 1), 1)
    gap = Keyword.get(props, :gap, 0)
    pad = Keyword.get(props, :padding, 0)
    inner_x = x + pad
    inner_y = y + pad
    inner_w = max(w - 2 * pad, 0)
    inner_h = max(h - 2 * pad, 0)
    cell_w = max(div(inner_w - (cols - 1) * gap, cols), 0)
    row_count = ceil(length(children) / cols)

    children
    |> Enum.with_index()
    |> Enum.flat_map(fn {child, idx} ->
      col = rem(idx, cols)
      row = div(idx, cols)
      cx = inner_x + col * (cell_w + gap)
      cy = inner_y + row * (cell_w + gap)
      cell_h = max(div(inner_h - (row_count - 1) * gap, row_count), 0)
      do_arrange(child, cx, cy, cell_w, cell_h, align, frame_h)
    end)
  end

  defp do_arrange(%Node{} = node, x, y, w, h, _align, _frame_h) do
    [%{node: node, x: x, y: y, w: max(w, 0), h: max(h, 0)}]
  end

  # Helper: detect if a column contains a status_bar child (returns its index or nil)
  defp status_bar_index(children) do
    Enum.find_index(children, &(&1.tag == :status_bar))
  end

  @doc """
  Renders a node tree into a Frame of the given size.
  """
  @spec render_to_frame(Node.t() | nil, pos_integer(), pos_integer()) :: Frame.t()
  def render_to_frame(nil, w, h), do: Frame.new(w, h)

  def render_to_frame(%Node{} = node, w, h) do
    frame = Frame.new(w, h)
    placements = arrange(node, %{width: w, height: h})
    Enum.reduce(placements, frame, &draw_placement(&2, &1))
  end

  defp draw_placement(frame, %{node: %Node{tag: tag} = node, x: x, y: y, w: w, h: h}) do
    case tag do
      :text -> Frame.put_text(frame, x, y, Keyword.get(node.props, :content, ""))
      :rule -> Frame.put_text(frame, x, y, String.duplicate("─", max(w, 0)))
      :status_bar -> Frame.put_text(frame, x, y, Keyword.get(node.props, :content, ""))
      :box -> draw_box(frame, x, y, w, h, node)
      _ -> frame
    end
  end

  defp draw_box(frame, x, y, w, h, %Node{props: props, children: [child | _]}) do
    border = Keyword.get(props, :border, :none)
    padding = Keyword.get(props, :padding, 0)
    frame = draw_box_border(frame, x, y, w, h, border)

    if h > 2 and w > 2 do
      inner_w = max(w - 2 - 2 * padding, 0)
      inner_h = max(h - 2 - 2 * padding, 0)
      inner_x = x + 1 + padding
      inner_y = y + 1 + padding

      child_frame = Alaja.Layout.render_to_frame(child, inner_w, inner_h)
      overlay_at(frame, child_frame, inner_x, inner_y)
    else
      frame
    end
  end

  defp overlay_at(%Alaja.Frame{buffer: buf} = frame, child_frame, x, y) do
    child_buf = child_frame.buffer

    new_buf =
      Enum.reduce(0..(child_buf.height - 1), buf, fn cy, acc ->
        Enum.reduce(0..(child_buf.width - 1), acc, fn cx, acc2 ->
          copy_cell(acc2, child_buf, cx, cy, x, y)
        end)
      end)

    %Alaja.Frame{frame | buffer: new_buf}
  end

  defp copy_cell(acc2, child_buf, cx, cy, x, y) do
    case Alaja.Buffer.get(child_buf, cx, cy) do
      %Alaja.Cell{char: c, fg: fg, bg: bg, effects: effects} ->
        if c != " " or fg != nil or bg != nil or effects != [] do
          Alaja.Buffer.put(acc2, x - 1 + cx, y - 1 + cy, c, fg, bg)
        else
          acc2
        end

      _ ->
        acc2
    end
  end

  defp draw_box_border(frame, _x, _y, _w, _h, :none), do: frame

  defp draw_box_border(frame, x, y, w, h, _border) do
    inner_h = max(h - 2, 0)
    inner_w = max(w - 2, 0)

    frame =
      if h >= 1 do
        Frame.put_text(frame, x, y, "┌" <> String.duplicate("─", inner_w) <> "┐")
      else
        frame
      end

    frame =
      Enum.reduce(1..inner_h, frame, fn dy, f ->
        if dy >= h do
          f
        else
          Frame.put_text(f, x, y + dy, "│" <> String.duplicate(" ", inner_w) <> "│")
        end
      end)

    if h >= 2 do
      Frame.put_text(frame, x, y + h - 1, "└" <> String.duplicate("─", inner_w) <> "┘")
    else
      frame
    end
  end
end
