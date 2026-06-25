defmodule Alaja.Components.Box do
  @moduledoc """
  Static box/container with borders for terminal output.

  Renders a bordered box around content, with optional title.

  ## Usage

      iex> Alaja.Components.Box.print("Hello, world!", title: "Greeting")
      # ╭─ Greeting ──────╮
      # │ Hello, world!   │
      # ╰─────────────────╯

  ## As a wrapper (post-processor)

  As of v0.3.0, `render/2` accepts a `String.t()`,
  `[String.t()]`, OR an `Alaja.Buffer.t()` as its content. When passed
  a Buffer, the box wraps it at the buffer's exact width — this is the
  foundation for composing components inside boxes. The result is
  always a Buffer (Buffer-in, Buffer-out).

  ## Cell engine

  `render/2` returns an `Alaja.Buffer.t/0`. The width is determined
  by the content's width plus padding. If the content is a Buffer,
  width is taken from `buffer.width + padding * 2`.
  """

  alias Alaja.{Buffer, Cell}

  @borders %{
    none: %{tl: "", tr: "", bl: "", br: "", h: "", v: "", mt: "", mb: ""},
    single: %{tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│", mt: "┬", mb: "┴"},
    double: %{tl: "╔", tr: "╗", bl: "╚", br: "╝", h: "═", v: "║", mt: "╦", mb: "╩"},
    rounded: %{tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│", mt: "┬", mb: "┴"},
    bold: %{tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃", mt: "┳", mb: "┻"}
  }

  @default_border_color {0, 180, 216}

  @type content :: String.t() | [String.t()] | Buffer.t()

  @doc """
  Prints a box around the given content.
  """
  @spec print(content(), keyword()) :: :ok
  def print(content, opts \\ []) do
    content
    |> render(opts)
    |> Buffer.to_iodata()
    |> IO.write()
  end

  @doc """
  Renders a box around `content` and returns an `Alaja.Buffer.t/0`.

  ## Options

  - `:title` - Optional title in the top border
  - `:border` - Border style (default `:rounded`)
  - `:border_color` - RGB tuple for border color (default cyan)
  - `:width` - Inner content width (default: auto from content)
  - `:padding` - Inner horizontal padding (default 1)
  """
  @spec render(content(), keyword()) :: Buffer.t()
  def render(content, opts \\ []) do
    border_style = Keyword.get(opts, :border, :rounded)
    fg = Keyword.get(opts, :border_color, @default_border_color)
    padding = Keyword.get(opts, :padding, 1)

    b = Map.get(@borders, border_style, @borders.rounded)
    {inner_w, content_buffer} = prepare_content(content, padding)

    inner_w =
      case Keyword.get(opts, :title) do
        nil -> inner_w
        title -> max(inner_w, String.length(" #{title} ") + 2)
      end

    total_w = inner_w + 2
    total_h = content_buffer.height + 2

    buffer = Buffer.new(total_w, total_h)

    buffer =
      buffer
      |> draw_top_border(b, inner_w, Keyword.get(opts, :title), fg)
      |> draw_bottom_border(b, inner_w, fg)

    overlay_content(buffer, content_buffer, b, fg, padding)
  end

  # Returns {inner_width, content_buffer} — content_buffer has height
  # matching the content and width = inner_width (already padded).
  defp prepare_content(%Buffer{} = buf, padding) do
    inner_w = buf.width + padding * 2

    padded =
      buf
      |> Buffer.pad(inner_w, buf.height)

    {inner_w, padded}
  end

  defp prepare_content(content, padding) when is_binary(content) do
    lines = String.split(content, "\n")
    prepare_lines(lines, padding)
  end

  defp prepare_content(content, padding) when is_list(content) do
    prepare_lines(content, padding)
  end

  defp prepare_lines(lines, padding) do
    inner_w =
      lines
      |> Enum.map(&String.length/1)
      |> Enum.max(fn -> 0 end)
      |> Kernel.+(padding * 2)

    height = max(length(lines), 1)

    padded =
      lines
      |> Enum.map(fn line ->
        pad_visible(line, inner_w - padding * 2)
      end)
      |> Enum.with_index()
      |> Enum.reduce(Buffer.new(inner_w, height), fn {line, y}, buf ->
        write_line(buf, padding, y, line)
      end)

    {inner_w, padded}
  end

  defp pad_visible(text, target_width) do
    visible = String.length(text)
    padding_count = max(0, target_width - visible)
    text <> String.duplicate(" ", padding_count)
  end

  defp write_line(buffer, x, y, line) do
    line
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      Buffer.update_cell(buf, x + idx, y, Cell.new(char))
    end)
  end

  defp draw_top_border(buffer, b, width, nil, fg) do
    fill_row(buffer, 0, b.tl <> String.duplicate(b.h, width) <> b.tr, fg)
  end

  defp draw_top_border(buffer, b, width, title, fg) do
    title_str = " #{title} "
    title_len = String.length(title_str)
    fill = max(width - title_len - 2, 0)
    fill_row(buffer, 0, b.tl <> b.h <> title_str <> String.duplicate(b.h, fill + 1) <> b.tr, fg)
  end

  defp draw_bottom_border(buffer, b, width, fg) do
    fill_row(buffer, buffer.height - 1, b.bl <> String.duplicate(b.h, width) <> b.br, fg)
  end

  defp fill_row(buffer, y, string, fg) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, x}, buf ->
      Buffer.update_cell(buf, x, y, Cell.new(char, fg))
    end)
  end

  defp overlay_content(buffer, content, b, fg, padding) do
    # Side borders at x=0 and x=total_w-1
    buffer =
      Enum.reduce(1..(buffer.height - 2), buffer, fn y, buf ->
        buf
        |> Buffer.update_cell(0, y, Cell.new(b.v, fg))
        |> Buffer.update_cell(buffer.width - 1, y, Cell.new(b.v, fg))
      end)

    # Place content at offset (1, 1)
    Buffer.overlay(buffer, content, 1, 1)
  end
end