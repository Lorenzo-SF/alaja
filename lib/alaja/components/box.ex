defmodule Alaja.Components.Box do
  @moduledoc """
  Static box/container with borders for terminal output.

  Renders a bordered box around content, with optional title.

  ## Usage

      iex> Alaja.Components.Box.print("Hello, world!", title: "Greeting")
      # ╭─ Greeting ──────╮
      # │ Hello, world!   │
      # ╰─────────────────╯
  """

  @borders %{
    none: %{tl: "", tr: "", bl: "", br: "", h: "", v: "", mt: "", mb: ""},
    single: %{tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│", mt: "┬", mb: "┴"},
    double: %{tl: "╔", tr: "╗", bl: "╚", br: "╝", h: "═", v: "║", mt: "╦", mb: "╩"},
    rounded: %{tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│", mt: "┬", mb: "┴"},
    bold: %{tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃", mt: "┳", mb: "┻"}
  }

  @default_border_color {0, 180, 216}
  @ansi_regex ~r/\x1b\[[0-9;]*m/

  @doc """
  Prints a box around the given content.

  ## Options

  - `:title` - Optional title in the top border
  - `:border` - Border style: `:single | :double | :rounded | :bold | :none` (default: `:rounded`)
  - `:border_color` - RGB tuple for border color
  - `:width` - Inner content width (default: auto from content)
  - `:padding` - Inner horizontal padding (default: 1)
  """
  @spec print(String.t() | [String.t()], keyword()) :: :ok
  def print(content, opts \\ []) do
    content |> render(opts) |> IO.write()
  end

  @doc """
  Renders a box to iodata without printing.
  """
  @spec render(String.t() | [String.t()], keyword()) :: iodata()
  def render(content, opts \\ []) do
    title = Keyword.get(opts, :title)
    border_style = Keyword.get(opts, :border, :rounded)
    {br, bg, bb} = Keyword.get(opts, :border_color, @default_border_color)
    padding = Keyword.get(opts, :padding, 1)

    lines = normalize_lines(content)

    content_width =
      lines
      |> Enum.map(fn l -> l |> String.replace(@ansi_regex, "") |> String.length() end)
      |> Enum.max(fn -> 0 end)

    inner_width = Keyword.get(opts, :width, content_width + padding * 2)

    inner_width =
      if title do
        min_title_width = String.length(" #{title} ") + 2
        max(inner_width, min_title_width)
      else
        inner_width
      end

    b = Map.get(@borders, border_style, @borders.rounded)
    color_on = Pote.Orchestrator.to_ansi({br, bg, bb})
    reset = Alaja.ANSI.reset_attributes()

    top_border = build_top(b, inner_width, title, color_on, reset)

    content_lines =
      lines
      |> Enum.map(fn line ->
        build_content_line(b, line, inner_width, padding, color_on, reset)
      end)
      |> Enum.intersperse("\n")

    bottom_border = build_bottom(b, inner_width, color_on, reset)

    [top_border, "\n", content_lines, "\n", bottom_border, "\n"]
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec normalize_lines(String.t() | [String.t()]) :: [String.t()]
  defp normalize_lines(content) when is_binary(content), do: String.split(content, "\n")
  defp normalize_lines(content) when is_list(content), do: content

  defp build_top(b, width, nil, color_on, reset) do
    [color_on, b.tl, String.duplicate(b.h, width), b.tr, reset]
  end

  defp build_top(b, width, title, color_on, reset) do
    title_str = " #{title} "
    title_len = String.length(title_str)
    fill = max(width - title_len - 2, 0)
    [color_on, b.tl, b.h, title_str, String.duplicate(b.h, fill + 1), b.tr, reset]
  end

  defp build_content_line(b, line, width, padding, color_on, reset) do
    pad = String.duplicate(" ", padding)
    content_width = width - padding * 2
    line_padded = pad_visible(line, content_width)
    [color_on, b.v, reset, pad, line_padded, pad, color_on, b.v, reset]
  end

  defp pad_visible(text, target_width) do
    visible = text |> String.replace(@ansi_regex, "") |> String.length()
    padding = max(0, target_width - visible)
    text <> String.duplicate(" ", padding)
  end

  defp build_bottom(b, width, color_on, reset) do
    [color_on, b.bl, String.duplicate(b.h, width), b.br, reset]
  end
end
