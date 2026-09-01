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

  alias Alaja.Buffer.{Position, Range, Renderer, Writer}
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
    Writer.put(buffer, x, y, char, fg, bg)
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
    if Position.valid_coord?(buffer, x, y) do
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
  def range(%__MODULE__{} = buffer), do: Range.range(buffer)

  @doc """
  Updates a cell at the specified coordinates with a pre-existing cell struct.
  """
  @spec update_cell(t(), non_neg_integer(), non_neg_integer(), Cell.t()) :: t()
  def update_cell(%__MODULE__{} = buffer, x, y, %Cell{} = cell) do
    if Position.valid_coord?(buffer, x, y) do
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
    if Position.valid_coord?(buffer, x, y) do
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
  def valid_coord?(%__MODULE__{} = buffer, x, y), do: Position.valid_coord?(buffer, x, y)

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
    Range.fill(buffer, x1, y1, x2, y2, char, fg, bg)
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
    Range.fill_with_opts(buffer, x1, y1, x2, y2, opts)
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
    Range.merge_matrix(buffer, x_start, y_start, matrix)
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
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = buffer1, %__MODULE__{} = buffer2) do
    Range.merge(buffer1, buffer2)
  end

  @doc """
  Writes a character to the buffer (alias for put/5-6).
  """
  @spec write(t(), non_neg_integer(), non_neg_integer(), String.t()) :: t()
  def write(buffer, x, y, char) do
    Writer.write(buffer, x, y, char)
  end

  @doc """
  Writes a character with colors to the buffer (alias for put/5-6).
  """
  @spec write(t(), non_neg_integer(), non_neg_integer(), String.t(), Cell.color(), Cell.color()) ::
          t()
  def write(buffer, x, y, char, fg, bg) do
    Writer.write(buffer, x, y, char, fg, bg)
  end

  @doc """
  Writes a string with foreground color only (background transparent).
  """
  @spec write(t(), non_neg_integer(), non_neg_integer(), String.t(), Cell.color()) :: t()
  def write(buffer, x, y, string, fg) when is_tuple(fg) do
    Writer.write(buffer, x, y, string, fg)
  end

  @spec write(t(), non_neg_integer(), non_neg_integer(), String.t(), keyword()) :: t()
  def write(buffer, x, y, char, opts) when is_list(opts) do
    Writer.write(buffer, x, y, char, opts)
  end

  @doc """
  Writes a string (without colour parsing) to the buffer at the given
  position. Each grapheme is written individually left-to-right.

  Characters beyond the buffer width are silently skipped.
  """
  @spec write_string(t(), non_neg_integer(), non_neg_integer(), String.t()) :: t()
  def write_string(buffer, x, y, string) do
    Writer.write_string(buffer, x, y, string)
  end

  @doc false
  @spec to_iodata(t()) :: iodata()
  def to_iodata(%__MODULE__{} = buffer), do: Renderer.to_iodata(buffer)

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
    Renderer.overlay(dest, src, x_offset, y_offset)
  end

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
  def hstack(buffers, gap \\ 0) when is_list(buffers), do: Renderer.hstack(buffers, gap)

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
  def vstack(buffers, gap \\ 0) when is_list(buffers), do: Renderer.vstack(buffers, gap)

  @doc """
  Crops a buffer to a sub-region. Out-of-range bounds are clamped.
  Useful for slicing a layout into a window.

  ## Examples

      buf = Alaja.Buffer.new(10, 5)
      Alaja.Buffer.crop(buf, 2, 1, 5, 3)  # 5 cols x 3 rows starting at (2,1)
  """
  @spec crop(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          t()
  def crop(%__MODULE__{} = buffer, x, y, w, h), do: Range.crop(buffer, x, y, w, h)

  @doc """
  Pads a buffer to a target size. Negative padding is clamped to 0.
  Content stays at the top-left.

  ## Examples

      Alaja.Buffer.pad(buf, 10, 5)  # buf becomes 10 cols x 5 rows, padded right/bottom
  """
  @spec pad(t(), non_neg_integer(), non_neg_integer()) :: t()
  def pad(%__MODULE__{} = buffer, target_w, target_h), do: Range.pad(buffer, target_w, target_h)

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
    Position.with_offset(buffer, x, y)
  end

  @doc """
  Returns `true` if the buffer has a non-zero offset set via `with_offset/3`.

  Useful when composing layouts: a positioned buffer overlays differently
  than an unpositioned one.
  """
  @spec positioned?(t()) :: boolean()
  def positioned?(%__MODULE__{} = buffer), do: Position.positioned?(buffer)
end
