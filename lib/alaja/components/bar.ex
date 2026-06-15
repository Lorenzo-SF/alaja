defmodule Alaja.Components.Bar do
  @moduledoc """
  Static progress bar component for terminal output.

  Renders a horizontal bar representing a value as a proportion of a maximum.

  ## Usage

      iex> Alaja.Components.Bar.print(75, 100)
      # [▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░] 75%

      iex> Alaja.Components.Bar.print(0.6, 1.0, label: "CPU", width: 40)
      # CPU [▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░] 60%
  """

  @filled_char "▓"
  @empty_char "░"
  @default_filled_color {0, 180, 216}
  @default_empty_color {50, 50, 50}

  @doc """
  Prints a progress bar directly to stdout.

  ## Parameters

  - `value` - Current value (numeric)
  - `max` - Maximum value (numeric, default: 100)

  ## Options

  - `:label` - Optional label prefix
  - `:show_percent` - Show percentage at end (default: true)
  - `:width` - Bar width in chars (default: 40)
  - `:filled_char` - Character for filled portion (default: `"▓"`)
  - `:empty_char` - Character for empty portion (default: `"░"`)
  - `:filled_color` - RGB tuple for filled section
  - `:empty_color` - RGB tuple for empty section
  """
  @spec print(number(), number(), keyword()) :: :ok
  def print(value, max \\ 100, opts \\ []) do
    value |> render(max, opts) |> IO.write()
    IO.puts("")
  end

  @doc """
  Renders a progress bar to iodata without printing.
  """
  @spec render(number(), number(), keyword()) :: iodata()
  def render(value, max \\ 100, opts \\ []) do
    label = Keyword.get(opts, :label)
    show_percent = Keyword.get(opts, :show_percent, true)
    width = Keyword.get(opts, :width, 40)
    filled_char = Keyword.get(opts, :filled_char, @filled_char)
    empty_char = Keyword.get(opts, :empty_char, @empty_char)
    {fr, fg, fb} = Keyword.get(opts, :filled_color, @default_filled_color)
    {er, eg, eb} = Keyword.get(opts, :empty_color, @default_empty_color)

    ratio = if max > 0, do: min(max(value / max, 0.0), 1.0), else: 0.0
    filled = round(ratio * width)
    empty = width - filled

    percent_str = if show_percent, do: " #{round(ratio * 100)}%", else: ""
    label_str = if label, do: "#{label} ", else: ""

    [
      label_str,
      "[",
      Pote.Orchestrator.to_ansi({fr, fg, fb}),
      String.duplicate(filled_char, filled),
      Pote.Orchestrator.to_ansi({er, eg, eb}),
      String.duplicate(empty_char, empty),
      Alaja.ANSI.reset_attributes(),
      "]",
      percent_str
    ]
  end
end
