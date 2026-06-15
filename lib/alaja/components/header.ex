defmodule Alaja.Components.Header do
  @moduledoc """
  Static header component for terminal output.

  Renders a centered title with optional subtitle and decorative lines.
  Used by the CLI `alaja show` commands and for formatted terminal output.

  ## Usage

      iex> Alaja.Components.Header.print("My App", subtitle: "v1.0.0")
      # Prints a formatted header to stdout

      iex> Alaja.Components.Header.render("My App", size: :large)
      # Returns iodata (does not print)
  """

  @type size :: :small | :medium | :large
  @type color :: {0..255, 0..255, 0..255} | nil

  @default_color {0, 180, 216}
  @default_subtitle_color {128, 128, 128}

  @doc """
  Prints a header directly to stdout.

  ## Options

  - `:subtitle` - Optional subtitle string
  - `:size` - `:small | :medium | :large` (default: `:medium`)
  - `:color` - RGB tuple for title color (default: cyan)
  - `:subtitle_color` - RGB tuple for subtitle color (default: gray)
  - `:width` - Total width in characters (default: terminal width or 80)
  """
  @spec print(String.t(), keyword()) :: :ok
  def print(title, opts \\ []) do
    title |> render(opts) |> IO.write()
    IO.puts("")
  end

  @doc """
  Renders a header to iodata without printing.
  """
  @spec render(String.t(), keyword()) :: iodata()
  def render(title, opts \\ []) do
    subtitle = Keyword.get(opts, :subtitle)
    size = Keyword.get(opts, :size, :medium)
    {cr, cg, cb} = Keyword.get(opts, :color) || @default_color
    {sr, sg, sb} = Keyword.get(opts, :subtitle_color) || @default_subtitle_color

    # --size now means width (actual character width of header)
    # Default to 80 if not specified
    width = Keyword.get(opts, :width, 80)

    {top_char, bottom_char, padding} = size_chars(size)

    separator_line = String.duplicate(top_char, width)
    bottom_line = String.duplicate(bottom_char, width)

    # Fix: Correct centering calculation
    # For centering: pad_leading to center the text, then pad_trailing to fill width
    title_len = String.length(title)
    title_left_pad = div(width - title_len, 2)

    # Correct: pad_leading to position, then pad_trailing to full width
    padded_title =
      String.pad_leading(title, title_left_pad + title_len) |> String.pad_trailing(width)

    header_parts = [
      Pote.Orchestrator.to_ansi({cr, cg, cb}),
      separator_line,
      "\n",
      String.duplicate(" ", padding),
      padded_title,
      "\n",
      bottom_line,
      Alaja.ANSI.reset_attributes()
    ]

    subtitle_part =
      if subtitle do
        # Correct subtitle centering - separate from title
        subtitle_len = String.length(subtitle)
        subtitle_left_pad = div(width - subtitle_len, 2)

        # Properly pad subtitle separately from title
        padded_sub =
          String.pad_leading(subtitle, subtitle_left_pad + subtitle_len)
          |> String.pad_trailing(width)

        ["\n", Pote.Orchestrator.to_ansi({sr, sg, sb}), padded_sub, Alaja.ANSI.reset_attributes()]
      else
        []
      end

    [header_parts, subtitle_part, "\n"]
  end

  # Returns {decoration_char, bottom_char, padding_lines} for each size
  # Now size is purely decorative - actual width comes from :width option
  @spec size_chars(size()) :: {String.t(), String.t(), non_neg_integer()}
  defp size_chars(:small), do: {"─", "─", 0}
  defp size_chars(:medium), do: {"═", "─", 0}
  defp size_chars(:large), do: {"█", "═", 0}
end
