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

  # Standard ANSI 16-color mapping (shared via Alaja.ANSI.standard_colors/0)
  @no_fg_change :"$no_fg_change"

  @borders %{
    none: %{tl: "", tr: "", bl: "", br: "", h: "", v: "", mt: "", mb: ""},
    single: %{tl: "┌", tr: "┐", bl: "└", br: "┘", h: "─", v: "│", mt: "┬", mb: "┴"},
    double: %{tl: "╔", tr: "╗", bl: "╚", br: "╝", h: "═", v: "║", mt: "╦", mb: "╩"},
    rounded: %{tl: "╭", tr: "╮", bl: "╰", br: "╯", h: "─", v: "│", mt: "┬", mb: "┴"},
    bold: %{tl: "┏", tr: "┓", bl: "┗", br: "┛", h: "━", v: "┃", mt: "┳", mb: "┻"}
  }

  @default_border_color :primary

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
  - `:border_color` - RGB tuple or theme atom for border color (default `:primary`)
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
    # Parse ANSI escapes into coloured cells so gradient / coloured
    # content preserves its colours inside the box. We measure visible
    # width separately (via strip_ansi) to size the container correctly.
    lines = String.split(content, "\n", trim: false)
    visible_lengths = lines |> Enum.map(&visible_length/1)
    inner_w = (visible_lengths |> Enum.max(fn -> 0 end)) + padding * 2
    height = max(length(lines), 1)

    padded =
      lines
      |> Enum.zip(visible_lengths)
      |> Enum.with_index()
      |> Enum.reduce(Buffer.new(inner_w, height), fn {{line, vlen}, y}, buf ->
        # Parse ANSI escapes, pad to target width, write coloured cells
        cells = parse_ansi_line(line)
        target = inner_w - padding * 2
        padded_cells = pad_cells(cells, target, vlen)
        write_coloured(buf, padding, y, padded_cells)
      end)

    {inner_w, padded}
  end

  defp prepare_content(content, padding) when is_list(content) do
    # Same as binary but each element is one line (no \n splitting)
    lines = content
    visible_lengths = lines |> Enum.map(&visible_length/1)
    inner_w = (visible_lengths |> Enum.max(fn -> 0 end)) + padding * 2
    height = max(length(lines), 1)

    padded =
      lines
      |> Enum.zip(visible_lengths)
      |> Enum.with_index()
      |> Enum.reduce(Buffer.new(inner_w, height), fn {{line, vlen}, y}, buf ->
        cells = parse_ansi_line(line)
        target = inner_w - padding * 2
        padded_cells = pad_cells(cells, target, vlen)
        write_coloured(buf, padding, y, padded_cells)
      end)

    {inner_w, padded}
  end

  # Helper: visible width of an ANSI-escaped string
  defp visible_length(text) do
    text |> strip_ansi() |> String.length()
  end

  @ansi_regex ~r/\e\[[0-9;]*m/

  defp strip_ansi(text) when is_binary(text) do
    String.replace(text, @ansi_regex, "")
  end

  # Pad a [{char, fg}] list to target width with spaces
  defp pad_cells(cells, target, current_vlen) do
    padding_count = max(0, target - current_vlen)
    cells ++ List.duplicate({" ", nil}, padding_count)
  end

  # Write coloured cells at (x, y) into the buffer
  defp write_coloured(buffer, x, y, cells) do
    cells
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {{char, fg}, idx}, buf ->
      Buffer.update_cell(buf, x + idx, y, Cell.new(char, fg))
    end)
  end

  # ---------------------------------------------------------------------------
  # ANSI parsing (extracts {char, fg} tuples from an ANSI-escaped string)
  # ---------------------------------------------------------------------------

  defp parse_ansi_line(line) do
    {cells, _fg} = parse_ansi_chars(line, [], nil)
    Enum.reverse(cells)
  end

  defp parse_ansi_chars("", acc, _fg), do: {acc, nil}

  defp parse_ansi_chars(<<0x1B, "[0m", rest::binary>>, acc, _fg) do
    parse_ansi_chars(rest, acc, nil)
  end

  defp parse_ansi_chars(<<0x1B, "[", rest::binary>>, acc, fg) do
    {skipped, after_m} = skip_until_m(rest)
    new_fg = resolve_ansi_fg(skipped, fg)
    parse_ansi_chars(after_m, acc, new_fg)
  end

  defp parse_ansi_chars(<<char::utf8, rest::binary>>, acc, fg) do
    parse_ansi_chars(rest, [{<<char::utf8>>, fg} | acc], fg)
  end

  defp parse_ansi_chars(<<_, rest::binary>>, acc, fg) do
    parse_ansi_chars(rest, acc, fg)
  end

  defp skip_until_m(<<?m, rest::binary>>), do: {"", rest}

  defp skip_until_m(<<c, rest::binary>>) do
    {skipped, after_m} = skip_until_m(rest)
    {<<c>> <> skipped, after_m}
  end

  defp skip_until_m(""), do: {"", ""}

  defp resolve_ansi_fg(skipped, current_fg) do
    case parse_ansi_fg(skipped) do
      @no_fg_change -> current_fg
      nil -> nil
      rgb -> rgb
    end
  end

  defp parse_ansi_fg(skipped) do
    cond do
      String.starts_with?(skipped, "38;2;") -> parse_ansi_truecolor(skipped)
      String.starts_with?(skipped, "38;5;") -> parse_ansi_xterm256(skipped)
      skipped == "39" -> nil
      byte_size(skipped) == 2 -> parse_ansi_standard_code(skipped)
      true -> @no_fg_change
    end
  end

  defp parse_ansi_truecolor(skipped) do
    rest = String.slice(skipped, 5, byte_size(skipped) - 5)
    parse_rgb_params(rest)
  end

  defp parse_ansi_xterm256(skipped) do
    rest = String.slice(skipped, 5, byte_size(skipped) - 5)

    with {n, ""} <- Integer.parse(rest),
         rgb when rgb != nil <- Map.get(Alaja.ANSI.standard_colors(), n) do
      rgb
    else
      _ -> @no_fg_change
    end
  end

  defp parse_ansi_standard_code(skipped) do
    case Integer.parse(skipped) do
      {n, ""} when n >= 30 and n <= 37 -> Map.get(Alaja.ANSI.standard_colors(), n - 30)
      {n, ""} when n >= 90 and n <= 97 -> Map.get(Alaja.ANSI.standard_colors(), n - 80)
      _ -> @no_fg_change
    end
  end

  defp parse_rgb_params(params) do
    case String.split(params, ";") do
      [r, g, b] ->
        with {ri, ""} <- Integer.parse(r),
             {gi, ""} <- Integer.parse(g),
             {bi, ""} <- Integer.parse(b) do
          {ri, gi, bi}
        else
          _ -> nil
        end

      _ ->
        nil
    end
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

  defp overlay_content(buffer, content, b, fg, _padding) do
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
