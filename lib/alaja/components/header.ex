defmodule Alaja.Components.Header do
  @moduledoc """
  Static header component for terminal output.

  Renders a centered title with optional subtitle and decorative lines.

  ## Usage

      iex> Alaja.Components.Header.print("My App", subtitle: "v1.0.0")
      iex> Alaja.Components.Header.render("My App", size: :large)

  ## Cell engine

  As of v0.3.0, `render/2` returns an `Alaja.Buffer.t/0` (height 3 or 4
  depending on subtitle presence).

  ## Customisation

  * `:color` — single colour tuple/atom or a list of colours (one per
    line when the title spans multiple lines).
  * `:subtitle_color` — same semantics for the subtitle.
  * `:separator_char` — character used for the decorative lines
    (default: derived from `:size`).
  * `:separator_color` — colour(s) for the decorative lines.
  * `:separator_length` — numeric length override. The component
    clamps the final width to the current terminal width.
  """

  @type size :: :small | :medium | :large
  @type color :: {0..255, 0..255, 0..255} | nil

  alias Alaja.{Buffer, Cell, Terminal}

  @default_color :primary
  @default_subtitle_color :debug

  # Fractions of the terminal width used when `:size` is a named value.
  # `:tiny`  = 1/8, `:small` = 1/4, `:medium` = 1/2, `:large` = 100%.
  @size_fractions %{tiny: 0.125, small: 0.25, medium: 0.5, large: 1.0}

  @doc """
  Prints a header directly to stdout.
  """
  @spec print(String.t(), keyword()) :: :ok
  def print(title, opts \\ []) do
    title
    |> render(opts)
    |> Buffer.to_iodata()
    |> IO.write()

    IO.puts("")
  end

  @doc """
  Renders a header to an `Alaja.Buffer.t/0`.

  `:size` accepts either a named atom (`:tiny`, `:small`, `:medium`,
  `:large`) or a positive integer (exact column width). Named sizes are
  fractions of the terminal width (`tiny` = 1/8, `small` = 1/4,
  `medium` = 1/2, `large` = full width). `:width` is kept as a deprecated
  alias for an integer width; new callers should use `:size`.
  """
  @spec render(String.t(), keyword()) :: Buffer.t()
  def render(title, opts \\ []) do
    subtitle = Keyword.get(opts, :subtitle)
    width = resolve_width(opts)
    size = Keyword.get(opts, :size, :medium) || width_to_size(width)

    title_colors = colors_or_default(Keyword.get(opts, :color), @default_color)
    subtitle_colors = colors_or_default(Keyword.get(opts, :subtitle_color), @default_subtitle_color)

    separator_char = Keyword.get(opts, :separator_char) || default_separator_char(size)
    separator_colors = colors_or_default_raw(Keyword.get(opts, :separator_color), title_colors)

    bottom_separator_char =
      if size == :large, do: default_separator_char(:medium), else: default_separator_char(:small)

    width = max(width, longest_line_length([title, subtitle], separator_char))

    title_lines = split_lines(title)
    subtitle_lines = split_lines_if_present(subtitle)
    total_lines = total_height(title_lines, subtitle_lines)

    buffer = Buffer.new(width, total_lines)

    buffer
    |> paint_top_line(separator_char, separator_colors, width)
    |> paint_title_lines(title_lines, title_colors, width)
    |> paint_bottom_line(length(title_lines), bottom_separator_char, separator_colors, width)
    |> paint_subtitle_lines(subtitle, subtitle_lines, title_lines, subtitle_colors, width)
  end

  # `normalize_color_list/1` returns `nil` when the user passed `nil`.
  # Resolve that to a single-element list seeded with `default`, so the
  # downstream colour-cycling logic always has a value to index.
  defp colors_or_default(nil, default), do: [default]

  defp colors_or_default(value, _default),
    do: normalize_color_list(value) || [@default_color]

  # Same as `colors_or_default/2` but accepts an arbitrary fallback list
  # (the `:separator_color` falls back to `title_colors`, not a single
  # colour).
  defp colors_or_default_raw(nil, fallback), do: fallback

  defp colors_or_default_raw(value, _fallback),
    do: normalize_color_list(value) || [@default_color]

  defp split_lines_if_present(nil), do: []
  defp split_lines_if_present(text), do: split_lines(text)

  defp total_height(title_lines, subtitle_lines) do
    max(length(title_lines) + length(subtitle_lines) + 2, 3)
  end

  defp paint_top_line(buffer, char, colors, width) do
    fill_row(buffer, 0, char, Enum.at(colors, 0, @default_color), width)
  end

  defp paint_title_lines(buffer, title_lines, colors, width) do
    Enum.reduce(Enum.with_index(title_lines), {buffer, 1}, fn {line, i}, {buf, row} ->
      fg = Enum.at(colors, i, List.last(colors) || @default_color)
      {write_centered(buf, row + i, line, fg, width), row}
    end)
    |> elem(0)
  end

  defp paint_bottom_line(buffer, title_end_row, char, colors, width) do
    fg = Enum.at(colors, 1, List.first(colors) || @default_color)
    fill_row(buffer, title_end_row + 1, char, fg, width)
  end

  defp paint_subtitle_lines(buffer, nil, _subtitle_lines, _title_lines, _colors, _width),
    do: buffer

  defp paint_subtitle_lines(
         buffer,
         _subtitle,
         subtitle_lines,
         title_lines,
         colors,
         width
       ) do
    Enum.reduce(Enum.with_index(subtitle_lines), buffer, fn {line, i}, buf ->
      fg = Enum.at(colors, i, List.last(colors) || @default_subtitle_color)
      write_centered(buf, length(title_lines) + 2 + i, line, fg, width)
    end)
  end

  # Normalises a single colour, a list of colours, or nil into a list.
  defp normalize_color_list(nil), do: nil

  defp normalize_color_list(list) when is_list(list),
    do: Enum.reject(list, &is_nil/1)

  defp normalize_color_list(color), do: [color]

  # Splits a multi-line string. Supports `\n` as the canonical separator
  # and treats the `;` separator (used by the CLI for convenience) the
  # same way.
  defp split_lines(text) do
    text
    |> String.replace(";", "\n")
    |> String.split(~r/[\r\n]+/, trim: true)
  end

  defp default_separator_char(:tiny), do: "·"
  defp default_separator_char(:small), do: "─"
  defp default_separator_char(:medium), do: "═"
  defp default_separator_char(:large), do: "█"
  defp default_separator_char(_), do: "─"

  # `:size` may be an atom (named) or a positive integer (exact width).
  # `:width` is honoured for backward compatibility. Returns the integer
  # width actually used.
  defp resolve_width(opts) do
    case Keyword.get(opts, :size) do
      n when is_integer(n) and n > 0 ->
        n

      :tiny ->
        round(Terminal.width() * @size_fractions.tiny)

      :small ->
        round(Terminal.width() * @size_fractions.small)

      :medium ->
        round(Terminal.width() * @size_fractions.medium)

      :large ->
        Terminal.width()

      _ ->
        Keyword.get(opts, :width) || Terminal.width()
    end
  end

  # Map an integer width back to a named size (for separator-char
  # selection). Falls back to `:medium` for widths that don't match a
  # named bucket.
  defp width_to_size(width) when is_integer(width) do
    term_w = max(Terminal.width(), 1)

    cond do
      width <= round(term_w * 0.2) -> :tiny
      width <= round(term_w * 0.35) -> :small
      width <= round(term_w * 0.7) -> :medium
      true -> :large
    end
  end

  defp longest_line_length(parts, _separator_char) do
    parts
    |> Enum.reject(&is_nil/1)
    |> Enum.flat_map(&split_lines/1)
    |> Enum.map(&String.length/1)
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(2)
  end

  defp fill_row(buffer, y, char, fg, width) do
    Enum.reduce(0..(width - 1), buffer, fn x, buf ->
      Buffer.update_cell(buf, x, y, Cell.new(char, fg))
    end)
  end

  defp write_centered(buffer, y, string, fg, width) do
    str_len = String.length(string)
    x = div(width - str_len, 2)
    write_string(buffer, x, y, string, fg, width)
  end

  defp write_string(buffer, x, y, string, fg, width) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      target_x = x + idx

      if target_x < width and target_x >= 0 do
        Buffer.update_cell(buf, target_x, y, Cell.new(char, fg))
      else
        buf
      end
    end)
  end
end
