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

  defstruct [:width, :height, cells: {}]

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
end
