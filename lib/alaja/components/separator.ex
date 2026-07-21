defmodule Alaja.Components.Separator do
  @moduledoc """
  Static horizontal separator line for terminal output.

  ## Usage

      iex> Alaja.Components.Separator.print()
      # Prints ─────────────────────────────

      iex> Alaja.Components.Separator.print("Section Title")
      # Prints ─── Section Title ───────────

  ## Cell engine

  As of v0.3.0, `render/2` returns an `Alaja.Buffer.t/0`. Use
  `Alaja.Buffer.to_iodata/1` or `Alaja.Printer.print_buffer/2` to
  emit it; `print/2` does that for you.
  """

  alias Alaja.{Buffer, Cell}

  @default_char "─"
  @default_color :debug

  @doc """
  Prints a separator line directly to stdout.

  ## Options

  - `:char` - Character to use (default: `"─"`)
  - `:text` - Optional centered label
  - `:color` - RGB tuple (default: dark gray)
  - `:width` - Total width (default: 80)
  """
  @spec print(String.t() | nil, keyword()) :: :ok
  def print(text \\ nil, opts \\ []) do
    text
    |> render(opts)
    |> Buffer.to_iodata()
    |> IO.write()

    IO.puts("")
  end

  @doc """
  Renders a separator to an `Alaja.Buffer.t/0`.

  The buffer has height 1 and width matching `:width`. The optional
  centered text breaks the line into three segments (left fill, label,
  right fill), all rendered with the same foreground color.
  """
  @spec render(String.t() | nil, keyword()) :: Buffer.t()
  def render(text \\ nil, opts \\ []) do
    char = Keyword.get(opts, :char, @default_char)
    fg = Keyword.get(opts, :color) || @default_color
    width = Keyword.get(opts, :width, 80)

    buffer = Buffer.new(width, 1)

    if text do
      label = " #{text} "
      label_len = String.length(label)
      remaining = width - label_len
      left = div(remaining, 2)
      right = remaining - left

      buffer
      |> fill_cells(0, 0, left, char, fg)
      |> write_cells(left, 0, label, fg)
      |> fill_cells(left + label_len, 0, right, char, fg)
    else
      fill_cells(buffer, 0, 0, width, char, fg)
    end
  end

  defp fill_cells(buffer, x, y, count, char, fg) when count > 0 do
    Enum.reduce(0..(count - 1), buffer, fn offset, buf ->
      Buffer.put(buf, x + offset, y, char, fg)
    end)
  end

  defp fill_cells(buffer, _x, _y, 0, _char, _fg), do: buffer
  defp fill_cells(buffer, _x, _y, _count, _char, _fg), do: buffer

  defp write_cells(buffer, x, y, string, fg) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      target_x = x + idx

      if target_x < buffer.width do
        cell = Cell.new(char, fg, nil)
        Buffer.update_cell(buf, target_x, y, cell)
      else
        buf
      end
    end)
  end
end
