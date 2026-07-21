defmodule Alaja.Components.Table do
  @moduledoc """
  Component for rendering formatted tables with advanced layout.

  Supports tables with:
  - Optional headers separated from rows
  - Per-cell, per-row, or per-column formatting
  - Per-cell and full-table alignment
  - Colors and effects
  - Customizable borders (normal, rounded, double, none, custom)
  - Configurable padding
  - Border formatting (color, effects)
  - Full-table alignment (left, center, right)

  ## Options

  ### Data
  - `:headers` — List of headers (if not included in data)
  - `:rows` — List of rows (if not included in data)

  ### Header Formatting
  - `:headers_color` — Header color (atom, hex, or list per column)
  - `:headers_effects` — Header effects (list, or list of lists per column)
  - `:headers_align` — Header alignment (:left, :center, :right, or list)

  ### Row Formatting
  - `:rows_color` — Row color (atom, hex, or list per column)
  - `:rows_effects` — Row effects (list, or list of lists per column)
  - `:rows_align` — Row alignment (:left, :center, :right, or list)

  ### Specific Row Formatting
  - `:rows_0_color` — Row 0 color (atom, hex, or list per column)
  - `:rows_0_effects` — Row 0 effects
  - `:rows_0_align` — Row 0 alignment (:left, :center, :right, or list)
  - (Repeat for rows_1_, rows_2_, etc.)

  ### Border Formatting
  - `:border_color` — Border color
  - `:border_effects` — Border effects

  ### Table Style
  - `:table_border` — Border style (:normal, :rounded, :double, :none, :custom)
  - `:table_border_custom` — Map with custom border characters
  - `:padding` — Inner cell padding (default: 1)
  - `:table_align` — Full table alignment (:left, :center, :right)

  ## Examples

      # Headers separated from rows
      Alaja.Components.Table.print(
        headers: ["ID", "Name", "Email"],
        rows: [
          ["1", "Jake", "jake@nypd.com"],
          ["2", "Rosa", "rosa@nypd.com"]
        ],
        headers_color: :cyan,
        headers_effects: [:bold],
        rows_color: :white,
        table_border: :rounded,
        padding: 1
      )

      # Per-column formatting
      Alaja.Components.Table.print(
        headers: ["Name", "Age", "City"],
        rows: [["Jake", "35", "NYC"]],
        headers_color: [:cyan, :yellow, :magenta],
        headers_align: [:center, :right, :left]
      )

      # Specific row formatting
      Alaja.Components.Table.print(
        headers: ["Service", "Status"],
        rows: [["td-ai", "OK"], ["td-auth", "ERROR"]],
        rows_0_color: [:white, :green],
        rows_1_color: [:white, :red]
      )

      # Without headers
      Alaja.Components.Table.print(
        rows: [
          ["1", "Jake", "jake@nypd.com"],
          ["2", "Rosa", "rosa@nypd.com"]
        ],
        table_border: :double
      )

      # Border formatting
      Alaja.Components.Table.print(
        headers: ["ID", "Name"],
        rows: [["1", "Jake"]],
        border_color: :cyan,
        border_effects: [:bold]
      )

      # Table centered in terminal
      Alaja.Components.Table.print(
        headers: ["A", "B"],
        rows: [["1", "2"]],
        table_align: :center,
        table_border: :rounded
      )

  """

  alias Alaja.Buffer
  alias Alaja.Structures.ChunkText

  # Regex para strip ANSI sequences
  @ansi_regex ~r/\x1b\[[0-9;]*m/

  @type border_style :: :normal | :rounded | :double | :none | :custom
  @type align :: :left | :center | :right
  @type color :: atom() | String.t() | {integer(), integer(), integer()}
  @type effects :: list(atom())

  @border_chars %{
    normal: %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "─",
      vertical: "│",
      cross: "┼",
      top_t: "┬",
      bottom_t: "┴",
      left_t: "├",
      right_t: "┤"
    },
    rounded: %{
      top_left: "╭",
      top_right: "╮",
      bottom_left: "╰",
      bottom_right: "╯",
      horizontal: "─",
      vertical: "│",
      cross: "┼",
      top_t: "┬",
      bottom_t: "┴",
      left_t: "├",
      right_t: "┤"
    },
    double: %{
      top_left: "╔",
      top_right: "╗",
      bottom_left: "╚",
      bottom_right: "╝",
      horizontal: "═",
      vertical: "║",
      cross: "╬",
      top_t: "╦",
      bottom_t: "╩",
      left_t: "╠",
      right_t: "╣"
    },
    none: %{
      top_left: "",
      top_right: "",
      bottom_left: "",
      bottom_right: "",
      horizontal: "",
      vertical: "",
      cross: "",
      top_t: "",
      bottom_t: "",
      left_t: "",
      right_t: ""
    }
  }

  @default_border_style :normal
  @default_padding 1
  @default_align :left
  @default_table_align :left

  defmodule Config do
    @moduledoc false
    defstruct [
      :border_style,
      :border_chars,
      :padding,
      :table_align,
      :border_color,
      :border_effects,
      :offset_spaces,
      :offset_str,
      :horizontal_segments,
      :rendered_vertical
    ]
  end

  @doc """
  Prints a table to the terminal.

  If `:page_size` is set, enables interactive pagination:
  - `n` / `→` — next page
  - `p` / `←` — previous page
  - `g` — go to page (prompts for number)
  - `f` / `l` — first / last page
  - `q` / `Esc` — quit
  """
  @spec print(list() | keyword(), keyword()) :: :ok
  def print(data, opts \\ [])

  def print(data, opts) when is_list(data) do
    if Keyword.keyword?(data) do
      headers = Keyword.get(data, :headers)
      rows = Keyword.get(data, :rows, [])
      table_opts = Keyword.drop(data, [:headers, :rows])
      merged_opts = Keyword.merge(table_opts, opts)
      print_with_headers(headers, rows, merged_opts)
    else
      case data do
        [] -> :ok
        [headers | rows] -> print_with_headers(headers, rows, opts)
      end
    end
  end

  @doc """
  Renders a table to an `Alaja.Buffer.t/0` without printing.

  This is the Cell-engine render. Returns a composable `Buffer` that
  can be overlaid on other buffers or passed to `Alaja.Components.Box`.

  See `render_buffer/2` for the implementation.
  """
  @spec render(list() | keyword(), keyword()) :: Buffer.t()
  def render(data, opts \\ [])

  def render(data, opts) do
    render_buffer(data, opts)
  end

  # Legacy iodata path retained for backward compat with callers that
  # need a string. Use `render/2` (Buffer) for new code.
  @doc false
  @spec render_iodata(list() | keyword(), keyword()) :: String.t()
  def render_iodata(data, opts \\ []) do
    {headers, rows} = extract_headers_rows(data)
    merged_opts = Keyword.merge(opts, extract_table_opts(data))
    {headers, rows} = normalize_data(headers, rows)
    column_widths = calculate_column_widths([headers | rows])
    config = build_config(merged_opts, column_widths)

    rendered = build_table_string(headers, rows, column_widths, config, merged_opts)
    IO.iodata_to_binary(rendered)
  end

  defp extract_headers_rows([headers | rows]) when is_list(headers), do: {headers, rows}
  defp extract_headers_rows(_), do: {[], []}

  defp extract_table_opts(data) when is_list(data) and not is_tuple(hd(data)) do
    Keyword.take(data, [:border_color, :border_effects, :padding, :table_align, :table_border])
  end

  defp extract_table_opts(data), do: Keyword.drop(data, [:headers, :rows])

  # ---------------------------------------------------------------------------
  # Cell engine (v0.3.0)
  # ---------------------------------------------------------------------------
  #
  # Renders the table into an `Alaja.Buffer.t/0`. This is the foundation for
  # composition: tables can be placed inside boxes, stacked horizontally with
  # other components, or positioned at exact (x, y) coordinates via
  # `Alaja.Buffer.overlay/4`.
  #
  # We don't support every option from `render/2` here — just the core
  # layout (column widths, alignment, colors, borders). For exotic layouts
  # (per-cell colours, effects, custom borders) use `render/2` which still
  # returns iodata.
  @doc """
  Renders a table into an `Alaja.Buffer.t/0` (Cell engine, v0.3.0).

  Supports column widths, alignment, header/row colors, and the same
  border styles as `render/2`. Pagination is NOT supported here — for
  interactive tables, use `print/2`.

  ## Options

  Same as `render/2` but limited to layout-level options. Per-cell /
  per-row / per-column formatting is supported via the same keywords.
  """
  @spec render_buffer(list(), keyword()) :: Buffer.t()
  def render_buffer(data, opts \\ [])

  def render_buffer([headers | rows], opts) when is_list(headers) do
    do_render_buffer(headers, rows, opts)
  end

  def render_buffer(data, opts) do
    headers = Keyword.get(data, :headers)
    rows = Keyword.get(data, :rows, [])
    table_opts = Keyword.drop(data, [:headers, :rows])
    do_render_buffer(headers || [], rows, Keyword.merge(opts, table_opts))
  end

  # Build the table as iodata (with ANSI escapes embedded), then walk
  # each line and translate character-by-character into Buffer cells.
  # ANSI escape sequences become cell fg colour metadata; plain
  # characters become one cell each. This single path is the canonical
  # implementation: it reuses build_table_string/5 for ALL formatting
  # (per-cell colour, effects, align, header/row distinct rendering),
  # so render/2 is feature-complete without a parallel implementation.
  defp do_render_buffer(headers, rows, opts) do
    {headers, rows} = normalize_data(headers, rows)
    column_widths = calculate_column_widths([headers | rows])
    config = build_config(opts, column_widths)

    iodata = build_table_string(headers, rows, column_widths, config, opts)

    # Each line is a list of strings/iodata. Split on '\n' terminators
    # and translate each line into a Buffer row.
    lines = split_iodata_lines(iodata)
    iodata_to_buffer(lines)
  end

  # Walk the iodata, splitting into lines at every "\n". The iodata
  # produced by build_table_string has "\n" as a bare atom (not nested
  # in a string), so we can split without parsing.
  defp split_iodata_lines(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> String.split("\n", trim: true)
  end

  # Translate an array of text lines (with embedded ANSI escapes) into
  # a Buffer. Visible characters become one cell each with the current
  # fg colour; ANSI sequences update the current fg but emit no cells.
  defp iodata_to_buffer(lines) do
    parsed = Enum.map(lines, &parse_line/1)

    width =
      parsed
      |> Enum.map(&length/1)
      |> Enum.max(fn -> 0 end)

    height = length(parsed)
    buffer = Buffer.new(width, height)

    parsed
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {cells, y}, buf ->
      {final, _} =
        cells
        |> Enum.with_index()
        |> Enum.reduce({buf, 0}, fn {{char, fg}, _idx}, {b, x} ->
          {Buffer.put(b, x, y, char, fg), x + 1}
        end)

      final
    end)
  end

  # Walk a line of mixed text + ANSI escapes, returning [{char, fg}].
  # Fg is reset to nil on plain text or after a reset (\e[0m).
  defp parse_line(line) when is_binary(line) do
    {cells, _fg, _rest} = parse_chars(line, [], nil)
    Enum.reverse(cells)
  end

  defp parse_chars("", acc, fg), do: {acc, fg, ""}

  defp parse_chars(<<0x1B, "[0m", rest::binary>>, acc, _fg) do
    parse_chars(rest, acc, nil)
  end

  # True-colour fg: \e[38;2;R;G;Bm
  defp parse_chars(
         <<0x1B, "[38;2;", r::binary-8, ";", g::binary-8, ";", b::binary-8, "m", rest::binary>>,
         acc,
         fg
       ) do
    case {Integer.parse(r), Integer.parse(g), Integer.parse(b)} do
      {{ri, ""}, {gi, ""}, {bi, ""}} ->
        parse_chars(rest, acc, {ri, gi, bi})

      _ ->
        parse_chars(rest, acc, fg)
    end
  end

  # SGR reset / clear styles: \e[m
  defp parse_chars(<<0x1B, "[m", rest::binary>>, acc, fg) do
    parse_chars(rest, acc, fg)
  end

  # Any other escape sequence: skip until 'm'.
  defp parse_chars(<<0x1B, "[", rest::binary>>, acc, fg) do
    {skipped, after_rest} = skip_to_m(rest)
    parse_chars(after_rest, acc, apply_sgr(acc, fg, skipped))
  end

  defp parse_chars(<<0x1B, _::binary>>, acc, fg), do: {acc, fg, ""}

  defp parse_chars(<<char::utf8, rest::binary>>, acc, fg) do
    parse_chars(rest, [{<<char::utf8>>, fg} | acc], fg)
  end

  defp parse_chars(<<_, rest::binary>>, acc, fg) do
    parse_chars(rest, acc, fg)
  end

  defp skip_to_m(<<?m, rest::binary>>), do: {"", rest}

  defp skip_to_m(<<c, rest::binary>>) do
    {skipped, after_rest} = skip_to_m(rest)
    {<<c>> <> skipped, after_rest}
  end

  defp skip_to_m(""), do: {"", ""}

  # Sentinel for "not a foreground colour change" (effects, background codes, etc.)
  @no_fg_change :"$no_fg_change"

  # Minimal SGR application — we only care about fg colour updates
  # because the buffer pipeline doesn't carry effects (no italic/bold
  # in cells yet). Other SGR codes pass through the current fg unchanged.
  defp apply_sgr(_acc, fg, skipped) do
    case parse_fg_sgr(skipped) do
      @no_fg_change -> fg
      nil -> nil
      rgb -> rgb
    end
  end

  # Standard ANSI 16-color mapping indices: 0-7 standard, 8-15 bright.
  defp parse_fg_sgr(skipped) do
    cond do
      String.starts_with?(skipped, "38;2;") -> parse_truecolor_skip(skipped)
      String.starts_with?(skipped, "38;5;") -> parse_xterm256_skip(skipped)
      skipped == "39" -> nil
      byte_size(skipped) == 2 -> parse_standard_fg_code(skipped)
      true -> @no_fg_change
    end
  end

  defp parse_truecolor_skip(skipped) do
    rest = String.slice(skipped, 5, byte_size(skipped) - 5)
    parse_rgb_params(rest)
  end

  defp parse_xterm256_skip(skipped) do
    rest = String.slice(skipped, 5, byte_size(skipped) - 5)

    with {n, ""} <- Integer.parse(rest),
         rgb when rgb != nil <- Map.get(Alaja.ANSI.standard_colors(), n) do
      rgb
    else
      _ -> @no_fg_change
    end
  end

  defp parse_standard_fg_code(skipped) do
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

  defp build_table_string(headers, rows, widths, config, opts) do
    lines =
      if config.border_style != :none do
        top = build_top_border(widths, config)

        header_lines =
          if headers != [] and headers != nil do
            header = build_header_row(headers, widths, config, opts)
            header_sep = build_header_separator(widths, config)
            [header, header_sep]
          else
            []
          end

        data_rows = build_rows(rows, widths, config, opts)

        bottom = build_bottom_border(widths, config)

        [top | header_lines] ++ data_rows ++ [bottom]
      else
        # No border style - just header and data rows
        header_lines =
          if headers != [] and headers != nil do
            [build_header_row(headers, widths, config, opts)]
          else
            []
          end

        data_rows = build_rows(rows, widths, config, opts)
        header_lines ++ data_rows
      end

    # Lines already have trailing newlines, just flatten
    lines
  end

  defp print_with_headers(headers, rows, opts) do
    page_size = Keyword.get(opts, :page_size)

    if page_size && is_integer(page_size) && page_size > 0 && length(rows) > page_size do
      print_paginated(headers, rows, page_size, opts)
    else
      # Normalizar datos
      {headers, rows} = normalize_data(headers, rows)
      column_widths = calculate_column_widths([headers | rows])
      config = build_config(opts, column_widths)
      do_print_table(headers, rows, column_widths, config, opts)
    end
  end

  defp normalize_data(headers, rows) do
    num_header_cols = if headers != [] and headers != nil, do: length(headers), else: 0

    rows =
      if num_header_cols > 0 do
        Enum.map(rows, fn row -> Enum.take(row, num_header_cols) end)
      else
        rows
      end

    {headers, rows}
  end

  defp build_config(opts, column_widths) do
    border_style = Keyword.get(opts, :table_border, @default_border_style)
    border_chars = get_border_chars(border_style, Keyword.get(opts, :table_border_custom))
    padding = Keyword.get(opts, :padding, @default_padding)
    table_align = Keyword.get(opts, :table_align, Keyword.get(opts, :align, @default_table_align))
    table_width = calculate_table_width(column_widths, padding)
    offset_spaces = get_table_offset(table_width, table_align)
    offset_str = String.duplicate(" ", offset_spaces)

    border_color = Keyword.get(opts, :border_color)
    border_effects = Keyword.get(opts, :border_effects, [])

    rendered_vertical =
      if border_style != :none do
        render_formatted(border_chars.vertical, border_color, border_effects)
      else
        ""
      end

    horizontal = border_chars.horizontal

    horizontal_segments =
      if horizontal != "" do
        unique_widths = Enum.uniq(column_widths)

        segments_cache =
          Enum.into(unique_widths, %{}, fn w ->
            # Render each segment with border color applied - must match cell width
            segment = String.duplicate(horizontal, w + padding * 2 + 4)
            {w, render_formatted(segment, border_color, border_effects)}
          end)

        Enum.map(column_widths, fn w -> Map.get(segments_cache, w) end)
      else
        Enum.map(column_widths, fn _ -> "" end)
      end

    %Config{
      border_style: border_style,
      border_chars: border_chars,
      padding: padding,
      table_align: table_align,
      border_color: border_color,
      border_effects: border_effects,
      offset_spaces: offset_spaces,
      offset_str: offset_str,
      horizontal_segments: horizontal_segments,
      rendered_vertical: rendered_vertical
    }
  end

  defp do_print_table(headers, rows, widths, config, opts) do
    if config.border_style != :none, do: print_top_border(widths, config)

    if headers != [] and headers != nil do
      print_header_row(headers, widths, config, opts)
      if rows != [], do: print_header_separator(widths, config)
    end

    print_rows(rows, widths, config, opts)

    if config.border_style != :none, do: print_bottom_border(widths, config)

    :ok
  end

  defp build_top_border(_widths, config) do
    border_chars = config.border_chars
    border_color = config.border_color

    # Use pre-rendered horizontal segments from config (includes color)
    segments = config.horizontal_segments

    top_left = render_formatted(border_chars.top_left, border_color, config.border_effects)
    top_t = render_formatted(border_chars.top_t, border_color, config.border_effects)
    top_right = render_formatted(border_chars.top_right, border_color, config.border_effects)

    [
      config.offset_str,
      top_left,
      Enum.intersperse(segments, top_t),
      top_right,
      "\n"
    ]
  end

  defp build_header_separator(_widths, config) do
    border_chars = config.border_chars
    border_color = config.border_color

    # Use pre-rendered horizontal segments from config (includes color)
    segments = config.horizontal_segments

    left_t = render_formatted(border_chars.left_t, border_color, config.border_effects)
    cross = render_formatted(border_chars.cross, border_color, config.border_effects)
    right_t = render_formatted(border_chars.right_t, border_color, config.border_effects)

    [
      config.offset_str,
      left_t,
      Enum.intersperse(segments, cross),
      right_t,
      "\n"
    ]
  end

  defp build_bottom_border(_widths, config) do
    border_chars = config.border_chars
    border_color = config.border_color

    # Use pre-rendered horizontal segments from config (includes color)
    segments = config.horizontal_segments

    bottom_left = render_formatted(border_chars.bottom_left, border_color, config.border_effects)
    bottom_t = render_formatted(border_chars.bottom_t, border_color, config.border_effects)

    bottom_right =
      render_formatted(border_chars.bottom_right, border_color, config.border_effects)

    [
      config.offset_str,
      bottom_left,
      Enum.intersperse(segments, bottom_t),
      bottom_right,
      "\n"
    ]
  end

  defp build_header_row(headers, widths, config, opts) do
    border_chars = config.border_chars
    border_color = config.border_color

    # Get header styling options
    headers_color = Keyword.get(opts, :headers_color)
    headers_effects = Keyword.get(opts, :headers_effects, [])
    headers_align = Keyword.get(opts, :headers_align, @default_align)

    # Render vertical border with color
    vertical = render_formatted(border_chars.vertical, border_color, config.border_effects)

    cells =
      headers
      |> Enum.with_index()
      |> Enum.map(fn {text, idx} ->
        width = Enum.at(widths, idx)
        cell_color = get_column_opts(idx, headers_color, nil)
        cell_effects = get_column_opts(idx, headers_effects, [])
        cell_align = get_column_opts(idx, headers_align, @default_align)
        aligned = apply_alignment(to_string(text), cell_align, width, config.padding)
        rendered = render_formatted(aligned, cell_color, cell_effects)
        rendered
      end)

    [
      config.offset_str,
      vertical,
      Enum.intersperse(cells, vertical),
      vertical,
      "\n"
    ]
  end

  defp build_rows(rows, widths, config, opts) do
    border_chars = config.border_chars
    border_color = config.border_color

    # Get row styling options
    rows_color = Keyword.get(opts, :rows_color)
    rows_effects = Keyword.get(opts, :rows_effects, [])
    rows_align = Keyword.get(opts, :rows_align, @default_align)

    # Extract row-specific options (same logic as print_rows)
    row_specific_opts = extract_row_specific_opts(opts)

    # Render vertical border with color
    vertical = render_formatted(border_chars.vertical, border_color, config.border_effects)

    # Use Enum.with_index to get row index for row-specific options
    rows_with_index = Enum.with_index(rows)

    Enum.map(rows_with_index, fn {row, row_index} ->
      # Get row-specific options for this row
      {row_color, row_effects, row_align} =
        get_row_opts(row_index, row_specific_opts, rows_color, rows_effects, rows_align)

      cells =
        row
        |> Enum.with_index()
        |> Enum.map(fn {text, idx} ->
          width = Enum.at(widths, idx, 10)
          cell_color = get_column_opts(idx, row_color, nil)
          cell_effects = get_column_opts(idx, row_effects, [])
          cell_align = get_column_opts(idx, row_align, @default_align)
          aligned = apply_alignment(to_string(text), cell_align, width, config.padding)
          rendered = render_formatted(aligned, cell_color, cell_effects)
          rendered
        end)

      [
        config.offset_str,
        vertical,
        Enum.intersperse(cells, vertical),
        vertical,
        "\n"
      ]
    end)
  end

  defp calculate_table_width(column_widths, padding) do
    # Ancho total = suma de anchos + padding + bordes
    # Cada columna: padding*2 (izq+der) + 2 (separadores internos) + 1 (borde derecho)
    Enum.sum(column_widths) + length(column_widths) * (padding * 2 + 2) + 1
  end

  defp get_table_offset(table_width, alignment) do
    {terminal_width, _} = Alaja.Terminal.size()

    case alignment do
      :center -> div(max(terminal_width - table_width, 0), 2)
      :right -> max(terminal_width - table_width, 0)
      _ -> 0
    end
  end

  defp extract_row_specific_opts(opts) do
    opts
    |> Enum.filter(fn {key, _value} ->
      key_string = Atom.to_string(key)

      # Handle both rows-N-color (hyphens) and rows_N_color (underscores)
      String.starts_with?(key_string, "rows") and
        (String.contains?(key_string, "color") or
           String.contains?(key_string, "effects") or
           String.contains?(key_string, "align"))
    end)
    |> Enum.map(fn {key, value} ->
      # Normalize key: convert hyphens to underscores if needed
      key_string = Atom.to_string(key) |> String.replace("-", "_")
      parts = String.split(key_string, "_")

      case parts do
        ["rows", row_num, opt_type] ->
          try do
            {String.to_integer(row_num), String.to_existing_atom(opt_type), value}
          rescue
            ArgumentError -> nil
          end

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(fn {row_num, _, _} -> row_num end)
  end

  defp get_row_opts(row_index, row_specific_opts, default_color, default_effects, default_align) do
    specific_opts = Map.get(row_specific_opts, row_index, [])

    color =
      case Enum.find(specific_opts, fn {_, opt_type, _} -> opt_type == :color end) do
        {_, _, value} when value != [] -> value
        _ -> default_color
      end

    effects =
      case Enum.find(specific_opts, fn {_, opt_type, _} -> opt_type == :effects end) do
        {_, _, value} when value != [] -> value
        _ -> default_effects
      end

    align =
      case Enum.find(specific_opts, fn {_, opt_type, _} -> opt_type == :align end) do
        {_, _, value} when value != nil -> value
        _ -> default_align
      end

    {color, effects, align}
  end

  defp get_border_chars(:custom, custom_borders) when is_map(custom_borders) do
    Map.merge(@border_chars.normal, custom_borders)
  end

  defp get_border_chars(:rounded, _custom), do: @border_chars.rounded
  defp get_border_chars(:double, _custom), do: @border_chars.double
  defp get_border_chars(:none, _custom), do: @border_chars.none
  defp get_border_chars(_style, _custom), do: @border_chars.normal

  defp calculate_column_widths(data) do
    # Filtrar rows vacías
    valid_data = Enum.reject(data, &(&1 == [] || !&1))

    if valid_data == [] do
      []
    else
      # Get the maximum number of columns
      max_columns = Enum.map(valid_data, &length/1) |> Enum.max(fn -> 0 end)

      # Calculate the maximum width for each column
      Enum.map(0..(max_columns - 1), fn col_index ->
        calculate_max_column_width(valid_data, col_index)
      end)
    end
  end

  defp calculate_max_column_width(data, col_index) do
    data
    |> Enum.map(fn row ->
      row |> Enum.at(col_index, "") |> to_string() |> visible_length()
    end)
    |> Enum.max(fn -> 0 end)
  end

  # Calculates the visible length of the text (excluding ANSI sequences)
  defp visible_length(text) do
    stripped = text |> String.replace(@ansi_regex, "")
    len = String.length(stripped)
    # IO.inspect({text, len}, label: "VISIBLE")
    len
  end

  defp print_top_border(widths, config) do
    print_border_line(
      widths,
      config.border_chars.top_left,
      config.border_chars.top_right,
      config.border_chars.horizontal,
      config.border_chars.top_t,
      config
    )
  end

  defp print_bottom_border(widths, config) do
    print_border_line(
      widths,
      config.border_chars.bottom_left,
      config.border_chars.bottom_right,
      config.border_chars.horizontal,
      config.border_chars.bottom_t,
      config
    )
  end

  defp print_header_separator(widths, config) do
    print_border_line(
      widths,
      config.border_chars.left_t,
      config.border_chars.right_t,
      config.border_chars.horizontal,
      config.border_chars.cross,
      config
    )
  end

  defp print_header_row(headers, widths, config, opts) do
    color = Keyword.get(opts, :headers_color)
    effects = Keyword.get(opts, :headers_effects, [])
    align = Keyword.get(opts, :headers_align, @default_align)
    print_row(headers, widths, color, effects, align, config)
  end

  defp print_rows(rows, widths, config, opts) do
    rows_color = Keyword.get(opts, :rows_color)
    rows_effects = Keyword.get(opts, :rows_effects, [])
    rows_align = Keyword.get(opts, :rows_align, @default_align)
    row_specific_opts = extract_row_specific_opts(opts)

    Enum.with_index(rows)
    |> Enum.each(fn {row, row_index} ->
      {color, effects, align} =
        get_row_opts(row_index, row_specific_opts, rows_color, rows_effects, rows_align)

      print_row(row, widths, color, effects, align, config)
    end)
  end

  defp print_border_line(_widths, left, right, _horizontal, sep, config) do
    # horizontal_segments already have color applied via render_formatted
    # We need to color the separator and insert it between segments
    sep_colored = render_formatted(sep, config.border_color, config.border_effects)

    # Join segments with colored separator, then add left/right with color
    middle = Enum.intersperse(config.horizontal_segments, sep_colored) |> IO.iodata_to_binary()
    left_formatted = render_formatted(left, config.border_color, config.border_effects)
    right_formatted = render_formatted(right, config.border_color, config.border_effects)
    line = "#{config.offset_str}#{left_formatted}#{middle}#{right_formatted}"
    # Already colored, just print without additional formatting
    IO.puts(line)
  end

  defp print_row(row, widths, color, effects, align, config) do
    filled_row = fill_row(row, length(widths))

    cells =
      filled_row
      |> Enum.with_index()
      |> Enum.map(fn {cell, i} ->
        width = Enum.at(widths, i, 0)
        cell_color = get_column_opts(i, color, nil)
        cell_effects = get_column_opts(i, effects, [])
        cell_align = get_column_opts(i, align, @default_align)
        aligned_str = apply_alignment(to_string(cell), cell_align, width, config.padding)
        render_formatted(aligned_str, cell_color, cell_effects)
      end)

    if config.border_style == :none do
      IO.puts(config.offset_str <> Enum.join(cells, "  "))
    else
      vertical = config.rendered_vertical

      line =
        "#{config.offset_str}#{vertical}" <>
          Enum.join(cells, "#{vertical}") <> "#{vertical}"

      IO.puts(line)
    end
  end

  defp fill_row(row, target_length) when is_list(row) and length(row) >= target_length, do: row

  defp fill_row(row, target_length) when is_list(row),
    do: row ++ List.duplicate("", target_length - length(row))

  defp fill_row(_, _), do: []

  defp apply_alignment(text, :left, width, padding) do
    total_left = 2 + padding
    total_right = 2 + padding
    inner = pad_visible(text, width)
    String.duplicate(" ", total_left) <> inner <> String.duplicate(" ", total_right)
  end

  defp apply_alignment(text, :center, width, padding) do
    total_left = 2 + padding
    total_right = 2 + padding
    inner = center_text(text, width)
    String.duplicate(" ", total_left) <> inner <> String.duplicate(" ", total_right)
  end

  defp apply_alignment(text, :right, width, padding) do
    total_left = 2 + padding
    total_right = 2 + padding
    inner = pad_visible_leading(text, width)
    String.duplicate(" ", total_left) <> inner <> String.duplicate(" ", total_right)
  end

  defp apply_alignment(text, _, width, padding) do
    apply_alignment(text, :left, width, padding)
  end

  # Rellena por la derecha basándose en longitud VISIBLE (ignora ANSI).
  defp pad_visible(text, width) do
    visible = visible_length(text)
    padding = max(0, width - visible)
    text <> String.duplicate(" ", padding)
  end

  # Rellena por la izquierda basándose en longitud VISIBLE.
  defp pad_visible_leading(text, width) do
    visible = visible_length(text)
    padding = max(0, width - visible)
    String.duplicate(" ", padding) <> text
  end

  # Centra basándose en longitud VISIBLE.
  defp center_text(text, width) do
    visible = visible_length(text)

    if visible >= width do
      text
    else
      total_pad = width - visible
      left_pad = div(total_pad, 2)
      right_pad = total_pad - left_pad
      String.duplicate(" ", left_pad) <> text <> String.duplicate(" ", right_pad)
    end
  end

  defp get_column_opts(column_index, column_opts, default_value) do
    case column_opts do
      list when is_list(list) and length(list) == 1 -> hd(list)
      list when is_list(list) -> Enum.at(list, column_index, default_value)
      value -> value
    end
  end

  defp render_formatted(text, nil, _effects), do: text

  defp render_formatted(text, color, effects) do
    if Alaja.Config.color_enabled?() do
      color_info = Pote.ColorInfo.new(color)

      ChunkText.render(ChunkText.new(text, color: color_info, effects: effects))
    else
      text
    end
  end

  # ── Interactive pagination ────────────────────────────────────────────

  defp print_paginated(headers, rows, page_size, opts) do
    total_rows = length(rows)
    total_pages = div(total_rows + page_size - 1, page_size)

    IO.write(Alaja.ANSI.hide_cursor())

    try do
      paginated_loop(headers, rows, 0, page_size, total_pages, opts)
    after
      IO.write(Alaja.ANSI.show_cursor())
    end
  end

  defp paginated_loop(headers, rows, page, page_size, total_pages, opts) do
    start = page * page_size
    page_rows = Enum.slice(rows, start, page_size)
    {headers, page_rows} = normalize_data(headers, page_rows)
    column_widths = calculate_column_widths([headers | page_rows])
    config = build_config(opts, column_widths)

    clear_screen_area()
    do_print_table(headers, page_rows, column_widths, config, opts)

    nav = "Page #{page + 1}/#{total_pages} | n=next  p=prev  f=first  l=last  g=goto  q=quit"
    IO.puts(String.duplicate(" ", max(config.offset_spaces - 2, 0)) <> "\e[2m" <> nav <> "\e[0m")
    IO.puts("")

    key = read_key()
    new_page = handle_navigation(key, page, total_pages)

    if new_page == :quit do
      :ok
    else
      paginated_loop(headers, rows, new_page, page_size, total_pages, opts)
    end
  end

  defp handle_navigation("n", page, total_pages), do: min(page + 1, total_pages - 1)
  defp handle_navigation("p", page, _total_pages), do: max(page - 1, 0)
  defp handle_navigation("f", _page, _total_pages), do: 0
  defp handle_navigation("l", _page, total_pages), do: total_pages - 1
  defp handle_navigation("g", _page, total_pages), do: goto_page(total_pages)
  defp handle_navigation("q", _page, _total_pages), do: :quit
  defp handle_navigation("\e", _page, _total_pages), do: :quit
  defp handle_navigation(_key, page, _total_pages), do: page

  defp goto_page(total_pages) do
    IO.write(Alaja.ANSI.show_cursor())
    IO.write("Go to page (1-#{total_pages}): ")
    input = IO.gets("") |> String.trim()

    case Integer.parse(input) do
      {n, _} when n >= 1 and n <= total_pages ->
        IO.write(Alaja.ANSI.hide_cursor())
        n - 1

      _ ->
        IO.write(Alaja.ANSI.hide_cursor())
        :stay
    end
  end

  defp read_key do
    case IO.gets("Press key: ") do
      :eof -> " "
      "" -> " "
      input -> String.first(String.trim(input)) || " "
    end
  end

  defp clear_screen_area do
    # Move cursor up past the previous render and clear
    # We use a simple approach: clear screen
    IO.write(Alaja.ANSI.clear_screen())
    IO.write(Alaja.ANSI.cursor_home())
  end
end
