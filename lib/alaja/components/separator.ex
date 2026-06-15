defmodule Alaja.Components.Separator do
  @moduledoc """
  Static horizontal separator line for terminal output.

  ## Usage

      iex> Alaja.Components.Separator.print()
      # Prints ─────────────────────────────

      iex> Alaja.Components.Separator.print("Section Title")
      # Prints ─── Section Title ───────────
  """

  @default_char "─"
  @default_color {64, 64, 64}

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
    text |> render(opts) |> IO.write()
    IO.puts("")
  end

  @doc """
  Renders a separator to iodata without printing.
  """
  @spec render(String.t() | nil, keyword()) :: iodata()
  def render(text \\ nil, opts \\ []) do
    char = Keyword.get(opts, :char, @default_char)
    {r, g, b} = Keyword.get(opts, :color) || @default_color
    width = Keyword.get(opts, :width, 80)

    line =
      if text do
        label = " #{text} "
        label_len = String.length(label)
        remaining = width - label_len
        left = div(remaining, 2)
        right = remaining - left

        [String.duplicate(char, max(left, 0)), label, String.duplicate(char, max(right, 0))]
        |> IO.iodata_to_binary()
      else
        String.duplicate(char, width)
      end

    [Pote.Orchestrator.to_ansi({r, g, b}), line, Alaja.ANSI.reset_attributes()]
  end
end
