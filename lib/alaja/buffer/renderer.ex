defmodule Alaja.Buffer.Renderer do
  @moduledoc false

  alias Alaja.Buffer
  alias Alaja.Cell
  alias Alaja.Buffer.Writer
  alias Alaja.Buffer.Position

  @doc false
  @spec to_iodata(Buffer.t()) :: iodata()
  def to_iodata(%Buffer{width: 0, height: 0}), do: []
  def to_iodata(%Buffer{} = buffer), do: do_to_iodata(buffer, 0, [])

  defp do_to_iodata(%Buffer{height: h}, y, acc) when y >= h do
    acc
  end

  defp do_to_iodata(%Buffer{width: w, height: h} = buffer, y, acc) do
    row_binary = do_row_to_iodata(buffer, y, 0, w, [], nil)

    row_binary =
      if y + 1 >= h do
        trim_trailing_visible(row_binary)
      else
        row_binary
      end

    next_acc = if y == 0, do: [row_binary], else: [acc, "\n", row_binary]

    do_to_iodata(buffer, y + 1, next_acc)
  end

  defp trim_trailing_visible(""), do: ""

  defp trim_trailing_visible(binary) do
    binary
    |> String.reverse()
    |> String.replace(~r/^[ ]+/, "")
    |> String.reverse()
  end

  defp do_row_to_iodata(_buffer, _y, x, w, acc, _prev) when x >= w do
    case acc do
      [] -> ""
      _ -> IO.iodata_to_binary(acc)
    end
  end

  defp do_row_to_iodata(buffer, y, x, w, acc, prev) do
    cell = Buffer.get(buffer, x, y)
    state = {cell.fg, cell.bg, cell.effects}
    prefix = Cell.to_ansi_prefix(cell)

    cond do
      prev == nil ->
        chunk =
          if prefix == [] do
            [acc, cell.char]
          else
            [acc, [prefix, cell.char]]
          end

        do_row_to_iodata(buffer, y, x + 1, w, chunk, state)

      state == prev ->
        new_acc = append_to_last(acc, cell.char)
        do_row_to_iodata(buffer, y, x + 1, w, new_acc, prev)

      true ->
        chunk =
          if prefix == [] do
            [acc, IO.ANSI.reset(), cell.char]
          else
            [acc, [IO.ANSI.reset(), prefix, cell.char]]
          end

        do_row_to_iodata(buffer, y, x + 1, w, chunk, state)
    end
  end

  defp append_to_last([], char), do: [char]

  defp append_to_last([head | tail], char) do
    [head | append_to_last(tail, char)]
  end

  @doc false
  @spec overlay(Buffer.t(), Buffer.t(), non_neg_integer(), non_neg_integer()) :: Buffer.t()
  def overlay(%Buffer{} = dest, %Buffer{} = src, x_offset, y_offset) do
    do_overlay(dest, src, x_offset, y_offset, 0)
  end

  defp do_overlay(dest, src, _x_offset, _y_offset, y) when y >= src.height do
    dest
  end

  defp do_overlay(dest, src, x_offset, y_offset, y) when y < src.height do
    result = do_overlay_row(dest, src, x_offset, y_offset + y, 0, y)
    do_overlay(result, src, x_offset, y_offset, y + 1)
  end

  defp do_overlay_row(dest, src, x_offset, dest_y, x, src_y) when x < src.width do
    src_cell = Buffer.get(src, x, src_y)
    target_x = x + x_offset
    target_y = dest_y

    if empty_cell?(src_cell) or not Position.valid_coord?(dest, target_x, target_y) do
      do_overlay_row(dest, src, x_offset, dest_y, x + 1, src_y)
    else
      dest2 = Writer.put_cell(dest, target_x, target_y, src_cell)
      do_overlay_row(dest2, src, x_offset, dest_y, x + 1, src_y)
    end
  end

  defp do_overlay_row(dest, _src, _x_offset, _dest_y, _x, _src_y), do: dest

  defp empty_cell?(%Cell{char: " ", fg: nil, bg: nil, effects: []}), do: true
  defp empty_cell?(%Cell{}), do: false

  @doc false
  @spec hstack([Buffer.t()], non_neg_integer()) :: Buffer.t()
  def hstack(buffers, gap \\ 0) when is_list(buffers) do
    case buffers do
      [] -> Buffer.new(0, 0)
      [single] -> single
      [first | rest] -> do_hstack(first, rest, gap, first.width, first.height)
    end
  end

  defp do_hstack(acc, [], _gap, acc_width, _max_h) do
    Alaja.Buffer.Range.expand_to_width(acc, acc_width)
  end

  defp do_hstack(acc, [next | rest], gap, acc_width, max_h) do
    new_x = acc_width + gap
    new_h = max(max_h, next.height)
    acc_padded = Alaja.Buffer.Range.expand_to_width(acc, new_x + next.width)
    acc_padded = Alaja.Buffer.Range.expand_to_height(acc_padded, new_h)
    next_expanded = Alaja.Buffer.Range.expand_to_height(next, new_h)
    merged = overlay(acc_padded, next_expanded, new_x, 0)
    do_hstack(merged, rest, gap, new_x + next.width, new_h)
  end

  @doc false
  @spec vstack([Buffer.t()], non_neg_integer()) :: Buffer.t()
  def vstack(buffers, gap \\ 0) when is_list(buffers) do
    case buffers do
      [] -> Buffer.new(0, 0)
      [single] -> single
      [first | rest] -> do_vstack(first, rest, gap, first.height, first.width)
    end
  end

  defp do_vstack(acc, [], _gap, acc_height, _max_w) do
    Alaja.Buffer.Range.expand_to_height(acc, acc_height)
  end

  defp do_vstack(acc, [next | rest], gap, acc_height, max_w) do
    new_y = acc_height + gap
    new_w = max(max_w, next.width)
    acc_padded = Alaja.Buffer.Range.expand_to_width(acc, new_w)
    acc_padded = Alaja.Buffer.Range.expand_to_height(acc_padded, new_y + next.height)
    next_expanded = Alaja.Buffer.Range.expand_to_width(next, new_w)
    merged = overlay(acc_padded, next_expanded, 0, new_y)
    do_vstack(merged, rest, gap, new_y + next.height, new_w)
  end
end
