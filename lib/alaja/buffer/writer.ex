defmodule Alaja.Buffer.Writer do
  @moduledoc false

  alias Alaja.Buffer
  alias Alaja.Cell

  @doc false
  @spec put(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          Cell.color(),
          Cell.color()
        ) ::
          Buffer.t()
  def put(%Buffer{} = buffer, x, y, char, fg \\ nil, bg \\ nil) do
    if Buffer.valid_coord?(buffer, x, y) do
      cell = Cell.new(char, fg, bg)
      index = y * buffer.width + x
      %{buffer | cells: put_elem(buffer.cells, index, cell)}
    else
      buffer
    end
  end

  @doc false
  @spec write(Buffer.t(), non_neg_integer(), non_neg_integer(), String.t()) :: Buffer.t()
  def write(buffer, x, y, char) do
    put(buffer, x, y, char)
  end

  @doc false
  @spec write(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          Cell.color(),
          Cell.color()
        ) :: Buffer.t()
  def write(buffer, x, y, char, fg, bg) do
    put(buffer, x, y, char, fg, bg)
  end

  @doc false
  @spec write(Buffer.t(), non_neg_integer(), non_neg_integer(), String.t(), Cell.color()) ::
          Buffer.t()
  def write(buffer, x, y, string, fg) when is_tuple(fg) do
    write_string_with_colors(buffer, x, y, string, fg, nil)
  end

  @doc false
  @spec write(Buffer.t(), non_neg_integer(), non_neg_integer(), String.t(), keyword()) ::
          Buffer.t()
  def write(buffer, x, y, char, opts) when is_list(opts) do
    fg = Keyword.get(opts, :fg)
    bg = Keyword.get(opts, :bg)
    put(buffer, x, y, char, fg, bg)
  end

  @doc false
  @spec write_string(Buffer.t(), non_neg_integer(), non_neg_integer(), String.t()) :: Buffer.t()
  def write_string(buffer, x, y, string) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      target_x = x + idx
      if target_x < buffer.width, do: put(buf, target_x, y, char), else: buf
    end)
  end

  @doc false
  @spec write_string_with_colors(
          Buffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          String.t(),
          Cell.color(),
          Cell.color()
        ) :: Buffer.t()
  def write_string_with_colors(buffer, x, y, string, fg, bg) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      put(buf, x + idx, y, char, fg, bg)
    end)
  end

  @doc false
  @spec put_cell(Buffer.t(), non_neg_integer(), non_neg_integer(), Cell.t()) :: Buffer.t()
  def put_cell(%Buffer{} = buffer, x, y, %Cell{} = cell) do
    if Buffer.valid_coord?(buffer, x, y) do
      index = y * buffer.width + x
      %{buffer | cells: put_elem(buffer.cells, index, cell)}
    else
      buffer
    end
  end
end
