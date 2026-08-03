defmodule Alaja.Frame do
  @moduledoc """
  An N×M terminal frame backed by `Alaja.Buffer`.

  A `Frame` is the unit of rendering: each `update` produces a new frame,
  and `Alaja.Renderer.diff/2` emits the minimal escape sequence to take
  the terminal from the previous frame to the next.

  This module is a thin facade over `Alaja.Buffer` that adds:

    * `width/height` shortcuts (`width/1`, `height/1`).
    * `put_text/4` for placing a string at `(x, y)` (right-padded with
      spaces).
    * `cells/1` for inspecting the frame.

  Use `Alaja.Frame.new/2` to allocate and `Alaja.Frame.put/4` or
  `put_text/4` to write.
  """

  alias Alaja.Buffer
  alias Alaja.Cell

  @type t :: %__MODULE__{buffer: Buffer.t()}

  defstruct [:buffer]

  @doc "Creates a new frame of the given size."
  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height) when is_integer(width) and width >= 0 and is_integer(height) and height >= 0 do
    %__MODULE__{buffer: Buffer.new(width, height)}
  end

  @doc "Width of the frame in cells."
  @spec width(t()) :: non_neg_integer()
  def width(%__MODULE__{buffer: b}), do: b.width

  @doc "Height of the frame in cells."
  @spec height(t()) :: non_neg_integer()
  def height(%__MODULE__{buffer: b}), do: b.height

  @doc "Returns the underlying buffer."
  @spec buffer(t()) :: Buffer.t()
  def buffer(%__MODULE__{buffer: b}), do: b

  @doc "Writes a single character at (x, y)."
  @spec put(t(), pos_integer(), pos_integer(), String.t() | Cell.t()) :: t()
  def put(%__MODULE__{} = f, x, y, char) when is_integer(x) and x > 0 and is_integer(y) and y > 0 do
    new_buf =
      case char do
        %Cell{} = cell -> Buffer.put(f.buffer, x - 1, y - 1, cell)
        str when is_binary(str) -> Buffer.put(f.buffer, x - 1, y - 1, str)
      end

    %__MODULE__{f | buffer: new_buf}
  end

  @doc "Writes a string at (x, y), padding with spaces to the frame width."
  @spec put_text(t(), pos_integer(), pos_integer(), String.t()) :: t()
  def put_text(%__MODULE__{} = f, x, y, text) when is_binary(text) and is_integer(x) and x > 0 and is_integer(y) and y > 0 do
    width = f.buffer.width
    start_col = x - 1
    row = y - 1

    {new_buf, _} =
      text
      |> String.graphemes()
      |> Enum.reduce({f.buffer, start_col}, fn ch, {b, col} ->
        if col >= width do
          {b, col}
        else
          {Buffer.put(b, col, row, ch), col + 1}
        end
      end)

    # pad remaining cells in the row with spaces up to width
    new_buf =
      Enum.reduce(start_col..(width - 1), new_buf, fn col, b ->
        if col < start_col + String.length(text) do
          b
        else
          Buffer.put(b, col, row, " ")
        end
      end)

    %__MODULE__{f | buffer: new_buf}
  end

  @doc "Clears the frame to all spaces."
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = f) do
    %__MODULE__{f | buffer: Buffer.new(f.buffer.width, f.buffer.height)}
  end

  @doc "Returns the cells as a map `%{{x, y} => char_string}`."
  @spec cells(t()) :: %{{pos_integer(), pos_integer()} => String.t()}
  def cells(%__MODULE__{buffer: buf}) do
    {w, h} = {buf.width, buf.height}

    Enum.reduce(0..(h - 1), %{}, fn y, acc ->
      Enum.reduce(0..(w - 1), acc, fn x, acc2 ->
        case Buffer.get(buf, x, y) do
          nil -> acc2
          %Cell{char: c} -> Map.put(acc2, {x + 1, y + 1}, c)
          str when is_binary(str) -> Map.put(acc2, {x + 1, y + 1}, str)
        end
      end)
    end)
  end

  @doc "Returns the text content of a single row, trimmed of trailing spaces."
  @spec row_text(t(), pos_integer()) :: String.t()
  def row_text(%__MODULE__{buffer: buf}, row) when is_integer(row) and row > 0 do
    width = buf.width

    0..(width - 1)
    |> Enum.map(fn x ->
      case Buffer.get(buf, x, row - 1) do
        nil -> " "
        %Cell{char: c} -> c
        str when is_binary(str) -> str
      end
    end)
    |> Enum.join("")
    |> String.trim_trailing()
  end
end
