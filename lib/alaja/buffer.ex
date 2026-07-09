defmodule Alaja.Buffer do
  @moduledoc """
  2D grid of cells for rendering terminal content.

  Uses a flat tuple for O(1) access per cell and minimal GC pressure.
  All operations are pure — they return a new buffer without mutating
  the original.

  ## Fields

  * `width` — visible width in columns.
  * `height` — visible height in rows.
  * `cells` — flat tuple indexed by `y * width + x`.

  ## Usage

      iex> buffer = Alaja.Buffer.new(80, 24)
      iex> buffer = Alaja.Buffer.put(buffer, 10, 5, "X", {255, 0, 0})
      iex> Alaja.Buffer.get(buffer, 10, 5)
  """

  alias Alaja.Cell

  @type cell :: Cell.t()
  @type coordinates :: {non_neg_integer(), non_neg_integer()}

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          cells: tuple()
        }

  defstruct [:width, :height, :offset_x, :offset_y, cells: {}]

  @doc """
  Creates a new buffer with the specified dimensions.

  Uses a flat tuple for O(1) access.

  ## Parameters

  - `width` - The width of the buffer in cells
  - `height` - The height of the buffer in cells

  ## Returns

  - A new buffer struct

  ## Examples

      iex> Buffer.new(80, 24)
      %Buffer{width: 80, height: 24, cells: {...}}
  """
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height) when width >= 0 and height >= 0 do
    size = width * height
    empty_cell = Cell.empty()
    cells = Tuple.duplicate(empty_cell, size)

    %__MODULE__{
      width: width,
      height: height,
      offset_x: 0,
      offset_y: 0,
      cells: cells
    }
  end

  @doc """
  Creates an empty buffer (width 0, height 0).
  """
  @spec create_empty_buffer() :: t()
  def create_empty_buffer do
    new(0, 0)
  end

  @doc """
  Puts a cell at the specified coordinates.

  ## Parameters

  - `buffer` - The buffer to modify
  - `x` - The x coordinate (0-based)
  - `y` - The y coordinate (0-based)
  - `char` - The character to place
  - `fg` - Optional foreground color as RGB tuple
  - `bg` - Optional background color as RGB tuple

  ## Returns

  - Updated buffer

  ## Examples

      iex> buffer = Buffer.new(10, 10)
      iex> buffer = Buffer.put(buffer, 5, 5, "X", {255, 0, 0}, {0, 0, 0})
      iex> Buffer.get(buffer, 5, 5).char
      "X"
  """
  @spec put(t(), non_neg_integer(), non_neg_integer(), String.t(), Cell.color(), Cell.color()) ::
          t()
  def put(%__MODULE__{} = buffer, x, y, char, fg \\ nil, bg \\ nil) do
    if valid_coord?(buffer, x, y) do
      cell = Cell.new(char, fg, bg)
      index = y * buffer.width + x
      %{buffer | cells: put_elem(buffer.cells, index, cell)}
    else
      buffer
    end
  end

  @doc """
  Gets the cell at the specified coordinates.

  ## Parameters

  - `buffer` - The buffer to read from
  - `x` - The x coordinate (0-based)
  - `y` - The y coordinate (0-based)

  ## Returns

  - The cell at the coordinates, or an empty cell if out of bounds

  ## Examples

      iex> buffer = Buffer.new(10, 10) |> Buffer.put(5, 5, "A", {255, 0, 0})
      iex> Buffer.get(buffer, 5, 5).char
      "A"

      iex> buffer = Buffer.new(10, 10)
      iex> Buffer.get(buffer, 100, 100).char
      " "
  """
  @spec get(t(), non_neg_integer(), non_neg_integer()) :: Cell.t()
  def get(%__MODULE__{} = buffer, x, y) do
    if valid_coord?(buffer, x, y) do
      index = y * buffer.width + x
      elem(buffer.cells, index)
    else
      Cell.empty()
    end
  end

  @doc """
  Gets the cell at the specified coordinates (alias for get/3).
  """
  @spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: Cell.t()
  def get_cell(%__MODULE__{} = buffer, x, y), do: get(buffer, x, y)

  @doc """
  Returns all coordinates in the buffer as a list of {x, y} tuples.
  """
  @spec range(t()) :: [{non_neg_integer(), non_neg_integer()}]
  def range(%__MODULE__{width: width, height: height}) when width > 0 and height > 0 do
    for y <- 0..(height - 1), x <- 0..(width - 1), do: {x, y}
  end

  def range(%__MODULE__{}), do: []

  @doc """
  Updates a cell at the specified coordinates with a pre-existing cell struct.
  """
  @spec update_cell(t(), non_neg_integer(), non_neg_integer(), Cell.t()) :: t()
  def update_cell(%__MODULE__{} = buffer, x, y, %Cell{} = cell) do
    if valid_coord?(buffer, x, y) do
      index = y * buffer.width + x
      %{buffer | cells: put_elem(buffer.cells, index, cell)}
    else
      buffer
    end
  end

  @doc """
  Updates a cell at the specified coordinates with character and optional colors.
  """
  @spec update_cell(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          Cell.color(),
          Cell.color()
        ) :: t()
  def update_cell(%__MODULE__{} = buffer, x, y, char, fg \\ nil, bg \\ nil) do
    if valid_coord?(buffer, x, y) do
      cell = Cell.new(char, fg, bg)
      index = y * buffer.width + x
      %{buffer | cells: put_elem(buffer.cells, index, cell)}
    else
      buffer
    end
  end

  @doc """
  Checks if the coordinates are within buffer bounds.

  ## Parameters

  - `buffer` - The buffer to check
  - `x` - The x coordinate
  - `y` - The y coordinate

  ## Returns

  - `true` if coordinates are valid
  - `false` otherwise
  """
  @spec valid_coord?(t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def valid_coord?(%__MODULE__{width: w, height: h}, x, y) do
    x >= 0 and x < w and y >= 0 and y < h
  end

  @doc """
  Clears all cells in the buffer.

  ## Parameters

  - `buffer` - The buffer to clear

  ## Returns

  - Buffer with all cells cleared

  ## Examples

      iex> buffer = Buffer.new(10, 10) |> Buffer.put(5, 5, "X", {255, 0, 0})
      iex> cleared = Buffer.clear(buffer)
      iex> Buffer.get(cleared, 5, 5).char
      " "
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = buffer) do
    empty_cell = Cell.empty()
    cells = Tuple.duplicate(empty_cell, buffer.width * buffer.height)
    %{buffer | cells: cells}
  end

  @doc """
  Fills a rectangular region with a cell.

  ## Parameters

  - `buffer` - The buffer to fill
  - `x1` - Starting x coordinate
  - `y1` - Starting y coordinate
  - `x2` - Ending x coordinate
  - `y2` - Ending y coordinate
  - `char` - Character to fill with
  - `fg` - Foreground color
  - `bg` - Background color

  ## Returns

  - Updated buffer
  """
  @spec fill(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          Cell.color(),
          Cell.color()
        ) :: t()
  def fill(%__MODULE__{} = buffer, x1, y1, x2, y2, char \\ " ", fg \\ nil, bg \\ nil) do
    cell = Cell.new(char, fg, bg)
    new_cells = fill_region(buffer.cells, buffer.width, x1, y1, x2, y2, cell)
    %{buffer | cells: new_cells}
  end

  defp fill_region(cells, _width, _x1, _y1, _x2, _y2, _cell) when tuple_size(cells) == 0,
    do: cells

  defp fill_region(cells, width, x1, y1, x2, y2, cell) do
    Enum.reduce(y1..y2, cells, fn y, acc ->
      Enum.reduce(x1..x2, acc, fn x, row_acc ->
        idx = y * width + x
        put_elem(row_acc, idx, cell)
      end)
    end)
  end

  @doc """
  Fill with keyword options (alternative API).
  """
  @spec fill_with_opts(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          keyword()
        ) :: t()
  def fill_with_opts(%__MODULE__{} = buffer, x1, y1, x2, y2, opts) do
    char = Keyword.get(opts, :char, " ")
    fg = Keyword.get(opts, :fg)
    bg = Keyword.get(opts, :bg)

    Enum.reduce(y1..y2, buffer, fn y, acc ->
      Enum.reduce(x1..x2, acc, fn x, buf ->
        put(buf, x, y, char, fg, bg)
      end)
    end)
  end

  @doc """
  Merges a matrix of cells into the buffer at specified position.

  ## Parameters

  - `buffer` - The buffer to merge into
  - `x_start` - Starting x coordinate
  - `y_start` - Starting y coordinate
  - `matrix` - 2D list of cells to merge

  ## Returns

  - Updated buffer
  """
  @spec merge_matrix(t(), non_neg_integer(), non_neg_integer(), [[Cell.t()]]) :: t()
  def merge_matrix(%__MODULE__{} = buffer, x_start, y_start, matrix) when is_list(matrix) do
    Enum.with_index(matrix)
    |> Enum.reduce(buffer, fn {row, dy}, acc ->
      Enum.with_index(row)
      |> Enum.reduce(acc, fn {cell, dx}, buf ->
        update_cell(buf, x_start + dx, y_start + dy, cell)
      end)
    end)
  end

  @doc """
  Merges two buffers. Cells from buffer2 override cells from buffer1.

  Useful for Z-index layering where higher Z buffers are merged on top.

  ## Parameters

  - `buffer1` - Base buffer
  - `buffer2` - Overlay buffer

  ## Returns

  - Merged buffer
  """
  @empty_cell Cell.empty()

  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = buffer1, %__MODULE__{} = buffer2) do
    merged_cells = zip_merge(buffer1.cells, buffer2.cells)
    %{buffer1 | cells: merged_cells}
  end

  defp zip_merge(c1, c2) when tuple_size(c1) == tuple_size(c2) do
    size = tuple_size(c1)
    do_zip_merge(c1, c2, size, 0, @empty_cell, [])
  end

  defp do_zip_merge(_c1, _c2, size, idx, _empty, acc) when idx >= size do
    List.to_tuple(Enum.reverse(acc))
  end

  defp do_zip_merge(c1, c2, size, idx, empty, acc) do
    c1_cell = elem(c1, idx)
    c2_cell = elem(c2, idx)
    new_acc = if c2_cell == empty, do: [c1_cell | acc], else: [c2_cell | acc]
    do_zip_merge(c1, c2, size, idx + 1, empty, new_acc)
  end

  @doc """
  Writes a character to the buffer (alias for put/5-6).
  """
  @spec write(t(), non_neg_integer(), non_neg_integer(), String.t()) :: t()
  def write(buffer, x, y, char) do
    put(buffer, x, y, char)
  end

  @doc """
  Writes a character with colors to the buffer (alias for put/5-6).
  """
  @spec write(t(), non_neg_integer(), non_neg_integer(), String.t(), Cell.color(), Cell.color()) ::
          t()
  def write(buffer, x, y, char, fg, bg) do
    put(buffer, x, y, char, fg, bg)
  end

  @doc """
  Writes a string with foreground color only (background transparent).
  """
  @spec write(t(), non_neg_integer(), non_neg_integer(), String.t(), Cell.color()) :: t()
  def write(buffer, x, y, string, fg) when is_tuple(fg) do
    write_string_with_colors(buffer, x, y, string, fg, nil)
  end

  # Writes a character with colors from keyword list (alias for put/5-6)
  @spec write(t(), non_neg_integer(), non_neg_integer(), String.t(), keyword()) :: t()
  def write(buffer, x, y, char, opts) when is_list(opts) do
    fg = Keyword.get(opts, :fg)
    bg = Keyword.get(opts, :bg)
    put(buffer, x, y, char, fg, bg)
  end

  @doc """
  Writes a string (without colour parsing) to the buffer at the given
  position. Each grapheme is written individually left-to-right.

  Characters beyond the buffer width are silently skipped.
  """
  @spec write_string(t(), non_neg_integer(), non_neg_integer(), String.t()) :: t()
  def write_string(buffer, x, y, string) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      target_x = x + idx
      if target_x < buffer.width, do: put(buf, target_x, y, char), else: buf
    end)
  end

  # Writes a string character by character with colors
  defp write_string_with_colors(buffer, x, y, string, fg, bg) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      put(buf, x + idx, y, char, fg, bg)
    end)
  end

  # ---------------------------------------------------------------------------
  # Composition primitives (Cell/Buffer engine unification, v0.3.0)
  # ---------------------------------------------------------------------------

  @doc """
  Converts a buffer to iodata by iterating cells row-by-row and emitting
  ANSI escapes via `Alaja.Cell.to_ansi/1`. Empty cells are coalesced into
  a single space; row ends get a `\n`.

  ## Examples

      iex> buffer = Alaja.Buffer.new(5, 1) |> Alaja.Buffer.put(0, 0, "H", {255, 0, 0})
      iex> Alaja.Buffer.to_iodata(buffer) |> IO.iodata_to_binary()
      \"\\e[38;2;255;0;0mH\\e[0m    \"
  """
  @spec to_iodata(t()) :: iodata()
  def to_iodata(%__MODULE__{width: 0, height: 0}), do: []
  def to_iodata(%__MODULE__{} = buffer), do: do_to_iodata(buffer, 0, [])

  defp do_to_iodata(%__MODULE__{height: h}, y, acc) when y >= h do
    acc
  end

  defp do_to_iodata(%__MODULE__{width: w, height: h} = buffer, y, acc) do
    row_binary = do_row_to_iodata(buffer, y, 0, w, [], nil)

    row_binary =
      if y + 1 >= h do
        # Final row: skip trailing whitespace but keep ANSI escapes
        trim_trailing_visible(row_binary)
      else
        row_binary
      end

    next_acc = if y == 0, do: [row_binary], else: [acc, "\n", row_binary]

    do_to_iodata(buffer, y + 1, next_acc)
  end

  # Removes trailing space characters from a binary that may contain
  # ANSI escape sequences. Used to clean up the final row.
  defp trim_trailing_visible(""), do: ""

  defp trim_trailing_visible(binary) do
    # Strip trailing spaces. ANSI escapes don't contain raw spaces
    # so this is safe — the last visible char on the last row is always
    # either a space or a printable char.
    binary
    |> String.reverse()
    |> String.replace(~r/^[ ]+/, "")
    |> String.reverse()
  end

  # Optimized row emitter: coalesces consecutive cells with the same
  # ANSI state into a single escape prefix + characters, then a single
  # reset. This is what makes output visually equivalent to the old
  # iodata-emitting components (one escape per colour change, not per
  # cell). `prev_state` tracks the last emitted fg/bg/effects so we
  # know when a new escape is needed.
  defp do_row_to_iodata(_buffer, _y, x, w, acc, _prev) when x >= w do
    case acc do
      [] -> ""
      _ -> IO.iodata_to_binary(acc)
    end
  end

  defp do_row_to_iodata(buffer, y, x, w, acc, prev) do
    cell = get(buffer, x, y)
    state = {cell.fg, cell.bg, cell.effects}
    prefix = Cell.to_ansi_prefix(cell)

    cond do
      # First cell ever
      prev == nil ->
        chunk =
          if prefix == [] do
            [acc, cell.char]
          else
            [acc, [prefix, cell.char]]
          end

        do_row_to_iodata(buffer, y, x + 1, w, chunk, state)

      # Same style as previous — append the char to acc as iolist
      state == prev ->
        new_acc = append_to_last(acc, cell.char)
        do_row_to_iodata(buffer, y, x + 1, w, new_acc, prev)

      # Style change
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

  # Appends a char to the rightmost position of an iolist.
  # Walks nested cons cells until reaching a binary, then appends.
  defp append_to_last([], char), do: [char]

  defp append_to_last([head | tail], char) do
    [head | append_to_last(tail, char)]
  end

  @doc """
  Overlays `src` onto `dest` at offset `(x, y)`. Cells outside the
  destination bounds are clipped. Empty cells in `src` (char `" "`,
  no fg, no bg, no effects) are skipped so they don't paint over
  content in `dest`.

  ## Examples

      dest = Alaja.Buffer.new(10, 1)
      src = Alaja.Buffer.new(3, 1) |> Alaja.Buffer.put(0, 0, "X", {255, 0, 0})
      Alaja.Buffer.overlay(dest, src, 2, 0)
  """
  @spec overlay(t(), t(), non_neg_integer(), non_neg_integer()) :: t()
  def overlay(%__MODULE__{} = dest, %__MODULE__{} = src, x_offset, y_offset) do
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
    src_cell = get(src, x, src_y)
    target_x = x + x_offset
    target_y = dest_y

    if empty_cell?(src_cell) or not valid_coord?(dest, target_x, target_y) do
      do_overlay_row(dest, src, x_offset, dest_y, x + 1, src_y)
    else
      dest2 = put_cell(dest, target_x, target_y, src_cell)
      do_overlay_row(dest2, src, x_offset, dest_y, x + 1, src_y)
    end
  end

  defp do_overlay_row(dest, _src, _x_offset, _dest_y, _x, _src_y), do: dest

  defp put_cell(%__MODULE__{} = buffer, x, y, %Cell{} = cell) do
    if valid_coord?(buffer, x, y) do
      index = y * buffer.width + x
      %{buffer | cells: put_elem(buffer.cells, index, cell)}
    else
      buffer
    end
  end

  defp extract_row(cells, start, count) do
    Enum.reduce(0..(count - 1), [], fn offset, acc ->
      [elem(cells, start + offset) | acc]
    end)
    |> Enum.reverse()
  end

  defp empty_cell?(%Cell{char: " ", fg: nil, bg: nil, effects: []}), do: true
  defp empty_cell?(%Cell{}), do: false

  @doc """
  Stacks buffers horizontally (left to right) with an optional gap
  (in columns) between them. Resulting buffer has `sum(widths) +
  gap * (n - 1)` columns and `max(heights)` rows. Buffers are
  top-aligned; shorter buffers get padded with empty rows at the
  bottom.

  ## Examples

      a = Alaja.Buffer.new(3, 1) |> Alaja.Buffer.put(0, 0, "A")
      b = Alaja.Buffer.new(3, 1) |> Alaja.Buffer.put(0, 0, "B")
      Alaja.Buffer.hstack([a, b], 1)
      # 7 cols x 1 row: 'A   B   '
  """
  @spec hstack([t()], non_neg_integer()) :: t()
  def hstack(buffers, gap \\ 0) when is_list(buffers) do
    case buffers do
      [] -> new(0, 0)
      [single] -> single
      [first | rest] -> do_hstack(first, rest, gap, first.width, first.height)
    end
  end

  defp do_hstack(acc, [], _gap, acc_width, _max_h), do: expand_to_width(acc, acc_width)

  defp do_hstack(acc, [next | rest], gap, acc_width, max_h) do
    new_x = acc_width + gap
    new_h = max(max_h, next.height)
    # Pad acc on the right to make room for next
    acc_padded = expand_to_width(acc, new_x + next.width)
    acc_padded = expand_to_height(acc_padded, new_h)
    next_expanded = expand_to_height(next, new_h)
    merged = overlay(acc_padded, next_expanded, new_x, 0)
    do_hstack(merged, rest, gap, new_x + next.width, new_h)
  end

  @doc """
  Stacks buffers vertically (top to bottom) with an optional gap (in
  rows) between them. Resulting buffer has `sum(heights) + gap * (n - 1)`
  rows and `max(widths)` columns. Buffers are left-aligned; narrower
  buffers get padded with empty columns on the right.

  ## Examples

      a = Alaja.Buffer.new(1, 2) |> Alaja.Buffer.put(0, 0, "A")
      b = Alaja.Buffer.new(1, 2) |> Alaja.Buffer.put(0, 0, "B")
      Alaja.Buffer.vstack([a, b], 1)
  """
  @spec vstack([t()], non_neg_integer()) :: t()
  def vstack(buffers, gap \\ 0) when is_list(buffers) do
    case buffers do
      [] -> new(0, 0)
      [single] -> single
      [first | rest] -> do_vstack(first, rest, gap, first.height, first.width)
    end
  end

  defp do_vstack(acc, [], _gap, acc_height, _max_w), do: expand_to_height(acc, acc_height)

  defp do_vstack(acc, [next | rest], gap, acc_height, max_w) do
    new_y = acc_height + gap
    new_w = max(max_w, next.width)
    acc_padded = expand_to_width(acc, new_w)
    acc_padded = expand_to_height(acc_padded, new_y + next.height)
    next_expanded = expand_to_width(next, new_w)
    merged = overlay(acc_padded, next_expanded, 0, new_y)
    do_vstack(merged, rest, gap, new_y + next.height, new_w)
  end

  defp expand_to_height(%__MODULE__{height: h} = buffer, h), do: buffer

  defp expand_to_height(%__MODULE__{width: w, height: h} = buffer, target_h) when target_h > h do
    new_cells =
      buffer.cells
      |> Tuple.to_list()
      |> Kernel.++(List.duplicate(Cell.empty(), w * (target_h - h)))

    %{buffer | height: target_h, cells: List.to_tuple(new_cells)}
  end

  defp expand_to_width(%__MODULE__{width: w} = buffer, w), do: buffer

  defp expand_to_width(%__MODULE__{width: w, height: h, cells: cells} = buffer, target_w)
       when target_w > w do
    cells_per_row = w
    new_cells_per_row = target_w
    pad_count = new_cells_per_row - cells_per_row

    rows =
      for y <- 0..(h - 1), reduce: [] do
        acc ->
          start = y * cells_per_row
          row_cells = extract_row(cells, start, cells_per_row)
          acc ++ row_cells ++ List.duplicate(Cell.empty(), pad_count)
      end

    %{buffer | width: target_w, cells: List.to_tuple(rows)}
  end

  @doc """
  Crops a buffer to a sub-region. Out-of-range bounds are clamped.
  Useful for slicing a layout into a window.

  ## Examples

      buf = Alaja.Buffer.new(10, 5)
      Alaja.Buffer.crop(buf, 2, 1, 5, 3)  # 5 cols x 3 rows starting at (2,1)
  """
  @spec crop(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          t()
  def crop(%__MODULE__{} = buffer, x, y, w, h) do
    x = max(0, min(x, buffer.width))
    y = max(0, min(y, buffer.height))
    w = max(0, min(w, buffer.width - x))
    h = max(0, min(h, buffer.height - y))

    new_cells =
      for row <- 0..(h - 1), reduce: [] do
        acc ->
          start = (y + row) * buffer.width + x
          row_cells = extract_row(buffer.cells, start, w)
          acc ++ row_cells
      end

    %{buffer | width: w, height: h, cells: List.to_tuple(new_cells)}
  end

  @doc """
  Pads a buffer to a target size. Negative padding is clamped to 0.
  Content stays at the top-left.

  ## Examples

      Alaja.Buffer.pad(buf, 10, 5)  # buf becomes 10 cols x 5 rows, padded right/bottom
  """
  @spec pad(t(), non_neg_integer(), non_neg_integer()) :: t()
  def pad(%__MODULE__{} = buffer, target_w, target_h) do
    buffer
    |> expand_to_width(max(target_w, buffer.width))
    |> expand_to_height(max(target_h, buffer.height))
  end

  @doc """
  Attaches a logical offset `(x, y)` to a buffer without copying cells. The
  buffer can later be rendered at this offset via
  `Alaja.Printer.print_buffer/2` or composed with `Alaja.Buffer.overlay/4`.

  Returns a new buffer struct with `offset_x` and `offset_y` set. Cells
  are NOT moved — this is purely metadata for layout composition.

  ## Examples

      buf = Alaja.Components.Table.render_buffer(headers: ["A"], rows: [["1"]])
      positioned = Alaja.Buffer.with_offset(buf, 10, 5)
      positioned.offset_x  # => 10
      positioned.offset_y  # => 5
  """
  @spec with_offset(t(), non_neg_integer(), non_neg_integer()) :: t()
  def with_offset(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    %{buffer | offset_x: x, offset_y: y}
  end

  @doc """
  Returns `true` if the buffer has a non-zero offset set via `with_offset/3`.

  Useful when composing layouts: a positioned buffer overlays differently
  than an unpositioned one.
  """
  @spec positioned?(t()) :: boolean()
  def positioned?(%__MODULE__{offset_x: 0, offset_y: 0}), do: false
  def positioned?(%__MODULE__{}), do: true
end
