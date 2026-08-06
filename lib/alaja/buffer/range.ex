defmodule Alaja.Buffer.Range do
  @moduledoc false

  alias Alaja.Buffer
  alias Alaja.Buffer.Writer
  alias Alaja.Cell

  @doc false
  @spec range(Buffer.t()) :: [{non_neg_integer(), non_neg_integer()}]
  def range(%Buffer{width: width, height: height}) when width > 0 and height > 0 do
    for y <- 0..(height - 1), x <- 0..(width - 1), do: {x, y}
  end

  def range(%Buffer{}), do: []

  @doc false
  @spec fill(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          Cell.color(),
          Cell.color()
        ) :: Buffer.t()
  def fill(%Buffer{} = buffer, x1, y1, x2, y2, char \\ " ", fg \\ nil, bg \\ nil) do
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

  @doc false
  @spec fill_with_opts(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          keyword()
        ) :: Buffer.t()
  def fill_with_opts(%Buffer{} = buffer, x1, y1, x2, y2, opts) do
    char = Keyword.get(opts, :char, " ")
    fg = Keyword.get(opts, :fg)
    bg = Keyword.get(opts, :bg)

    Enum.reduce(y1..y2, buffer, fn y, acc ->
      Enum.reduce(x1..x2, acc, fn x, buf ->
        Writer.put(buf, x, y, char, fg, bg)
      end)
    end)
  end

  @doc false
  @spec merge_matrix(Buffer.t(), non_neg_integer(), non_neg_integer(), [[Cell.t()]]) :: Buffer.t()
  def merge_matrix(%Buffer{} = buffer, x_start, y_start, matrix) when is_list(matrix) do
    Enum.with_index(matrix)
    |> Enum.reduce(buffer, fn {row, dy}, acc ->
      Enum.with_index(row)
      |> Enum.reduce(acc, fn {cell, dx}, buf ->
        Buffer.update_cell(buf, x_start + dx, y_start + dy, cell)
      end)
    end)
  end

  @empty_cell Cell.empty()

  @doc false
  @spec merge(Buffer.t(), Buffer.t()) :: Buffer.t()
  def merge(%Buffer{} = buffer1, %Buffer{} = buffer2) do
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

  defp extract_row(cells, start, count) do
    Enum.reduce(0..(count - 1), [], fn offset, acc ->
      [elem(cells, start + offset) | acc]
    end)
    |> Enum.reverse()
  end

  @doc false
  @spec crop(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          Buffer.t()
  def crop(%Buffer{} = buffer, x, y, w, h) do
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

  @doc false
  @spec pad(Buffer.t(), non_neg_integer(), non_neg_integer()) :: Buffer.t()
  def pad(%Buffer{} = buffer, target_w, target_h) do
    buffer
    |> expand_to_width(max(target_w, buffer.width))
    |> expand_to_height(max(target_h, buffer.height))
  end

  @doc false
  @spec expand_to_height(Buffer.t(), non_neg_integer()) :: Buffer.t()
  def expand_to_height(%Buffer{height: h} = buffer, h), do: buffer

  def expand_to_height(%Buffer{width: w, height: h} = buffer, target_h) when target_h > h do
    new_cells =
      buffer.cells
      |> Tuple.to_list()
      |> Kernel.++(List.duplicate(Cell.empty(), w * (target_h - h)))

    %{buffer | height: target_h, cells: List.to_tuple(new_cells)}
  end

  @doc false
  @spec expand_to_width(Buffer.t(), non_neg_integer()) :: Buffer.t()
  def expand_to_width(%Buffer{width: w} = buffer, w), do: buffer

  def expand_to_width(%Buffer{width: w, height: h, cells: cells} = buffer, target_w)
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
end
