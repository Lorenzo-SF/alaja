defmodule Alaja.Components.Bar do
  @moduledoc """
  Static progress bar component for terminal output.

  Renders a horizontal bar representing a value as a proportion of a maximum.

  ## Usage

      iex> Alaja.Components.Bar.print(75, 100)
      # [▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░] 75%

      iex> Alaja.Components.Bar.print(0.6, 1.0, label: "CPU", width: 40)
      # CPU [▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░] 60%

  ## Cell engine

  As of v0.3.0, `render/3` returns an `Alaja.Buffer.t/0`. The label and
  percent text are placed on the same row as the bar (left-aligned label,
  right-aligned percent).
  """

  alias Alaja.{Buffer, Cell}

  @filled_char "▓"
  @empty_char "░"
  @default_filled_color {0, 180, 216}
  @default_empty_color {50, 50, 50}

  @doc """
  Prints a progress bar directly to stdout.
  """
  @spec print(number(), number(), keyword()) :: :ok
  def print(value, max \\ 100, opts \\ []) do
    value
    |> render(max, opts)
    |> Buffer.to_iodata()
    |> IO.write()

    IO.puts("")
  end

  @doc """
  Renders a progress bar to an `Alaja.Buffer.t/0`.

  Layout (single row, total width = label_w + 1 + width + 1 + percent_w):
    [label ] [bar] [percent]
  """
  @spec render(number(), number(), keyword()) :: Buffer.t()
  def render(value, max \\ 100, opts \\ []) do
    label = Keyword.get(opts, :label)
    show_percent = Keyword.get(opts, :show_percent, true)
    width = Keyword.get(opts, :width, 40)
    filled_char = Keyword.get(opts, :filled_char, @filled_char)
    empty_char = Keyword.get(opts, :empty_char, @empty_char)
    filled_color = Keyword.get(opts, :filled_color, @default_filled_color)
    empty_color = Keyword.get(opts, :empty_color, @default_empty_color)

    ratio = if max > 0, do: min(max(value / max, 0.0), 1.0), else: 0.0
    filled = round(ratio * width)
    empty = width - filled

    percent_str = if show_percent, do: " #{round(ratio * 100)}%", else: ""
    label_str = if label, do: "#{label} ", else: ""

    total_w = String.length(label_str) + 2 + width + String.length(percent_str)
    buffer = Buffer.new(total_w, 1)
    x = 0

    buffer =
      buffer
      |> write_string(x, 0, label_str)
      |> write_brackets(x + String.length(label_str), 0)

    bar_x = x + String.length(label_str) + 1

    buffer =
      buffer
      |> fill_segment(bar_x, 0, filled, filled_char, filled_color)
      |> fill_segment(bar_x + filled, 0, empty, empty_char, empty_color)

    if show_percent do
      write_string(buffer, bar_x + width + 1, 0, percent_str)
    else
      buffer
    end
  end

  defp fill_segment(buffer, x, y, count, char, fg) when count > 0 do
    Enum.reduce(0..(count - 1), buffer, fn offset, buf ->
      cell = Cell.new(char, fg)
      Buffer.update_cell(buf, x + offset, y, cell)
    end)
  end

  defp fill_segment(buffer, _x, _y, 0, _char, _fg), do: buffer

  defp write_brackets(buffer, x, y) do
    buffer
    |> Buffer.update_cell(x, y, Cell.new("[", nil))
    |> Buffer.update_cell(x + 1, y, Cell.new("]", nil))
  end

  defp write_string(buffer, x, y, string) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      target_x = x + idx

      if target_x < buffer.width do
        Buffer.update_cell(buf, target_x, y, Cell.new(char, nil))
      else
        buf
      end
    end)
  end
end
