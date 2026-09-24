defmodule Alaja.Components.Table.Renderer do
  @moduledoc false

  alias Alaja.Buffer
  alias Alaja.Components.Table.{Borders, Calculator, Theme}

  @default_align :left
  @no_fg_change :"$no_fg_change"

  # SGR code -> Alaja.Cell effect atom. Used by the ANSI parser so
  # `--rows-effects`/`--row-N-effects` survive the round-trip through
  # iodata when the CLI builds a Buffer for `Printer.print_raw/2`.
  @sgr_to_effect %{
    "1" => :bold,
    "2" => :dim,
    "3" => :italic,
    "4" => :underline,
    "5" => :blink,
    "7" => :reverse,
    "8" => :hidden,
    "9" => :strikethrough
  }

  @spec build_table_string(
          list(),
          list(),
          list(integer()),
          Alaja.Components.Table.Config.t(),
          keyword()
        ) :: list()
  def build_table_string(headers, rows, widths, config, opts) do
    lines =
      if config.border_style != :none do
        top = Borders.build_top_border(widths, config)

        header_lines =
          if headers != [] and headers != nil do
            header = build_header_row(headers, widths, config, opts)
            header_sep = Borders.build_header_separator(widths, config)
            [header, header_sep]
          else
            []
          end

        data_rows = build_rows(rows, widths, config, opts)

        bottom = Borders.build_bottom_border(widths, config)

        [top | header_lines] ++ data_rows ++ [bottom]
      else
        header_lines =
          if headers != [] and headers != nil do
            [build_header_row(headers, widths, config, opts)]
          else
            []
          end

        data_rows = build_rows(rows, widths, config, opts)
        header_lines ++ data_rows
      end

    lines
  end

  @spec do_render_buffer(
          list(),
          list(),
          list(integer()),
          Alaja.Components.Table.Config.t(),
          keyword()
        ) ::
          Buffer.t()
  def do_render_buffer(headers, rows, column_widths, config, opts) do
    iodata = build_table_string(headers, rows, column_widths, config, opts)

    lines = split_iodata_lines(iodata)
    iodata_to_buffer(lines)
  end

  defp split_iodata_lines(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> String.split("\n", trim: true)
  end

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
        |> Enum.reduce({buf, 0}, fn {{char, fg, effects}, _idx}, {b, x} ->
          cell = %Alaja.Cell{char: char, fg: fg, bg: nil, effects: effects}
          {Buffer.update_cell(b, x, y, cell), x + 1}
        end)

      final
    end)
  end

  defp parse_line(line) when is_binary(line) do
    {cells, _fg, _effects, _rest} = parse_chars(line, [], nil, [])
    Enum.reverse(cells)
  end

  defp parse_chars("", acc, fg, effects), do: {acc, fg, effects, ""}

  # `\e[0m` resets BOTH foreground colour AND effects.
  defp parse_chars(<<0x1B, "[0m", rest::binary>>, acc, _fg, _effects) do
    parse_chars(rest, acc, nil, [])
  end

  defp parse_chars(
         <<0x1B, "[38;2;", r::binary-8, ";", g::binary-8, ";", b::binary-8, "m", rest::binary>>,
         acc,
         fg,
         effects
       ) do
    case {Integer.parse(r), Integer.parse(g), Integer.parse(b)} do
      {{ri, ""}, {gi, ""}, {bi, ""}} ->
        parse_chars(rest, acc, {ri, gi, bi}, effects)

      _ ->
        parse_chars(rest, acc, fg, effects)
    end
  end

  defp parse_chars(<<0x1B, "[m", rest::binary>>, acc, fg, effects) do
    parse_chars(rest, acc, fg, effects)
  end

  # Catch-all for `\e[...m` runs. `skip_to_m/1` returns the params
  # between `[` and `m`. We split on `;` so a single SGR can carry
  # multiple codes (e.g. `\e[1;3m` = bold + italic).
  defp parse_chars(<<0x1B, "[", rest::binary>>, acc, fg, effects) do
    {skipped, after_rest} = skip_to_m(rest)
    {new_fg, new_effects} = apply_sgr(fg, effects, skipped)
    parse_chars(after_rest, acc, new_fg, new_effects)
  end

  defp parse_chars(<<0x1B, _::binary>>, acc, fg, effects), do: {acc, fg, effects, ""}

  defp parse_chars(<<char::utf8, rest::binary>>, acc, fg, effects) do
    parse_chars(rest, [{<<char::utf8>>, fg, effects} | acc], fg, effects)
  end

  defp parse_chars(<<_, rest::binary>>, acc, fg, effects) do
    parse_chars(rest, acc, fg, effects)
  end

  defp skip_to_m(<<?m, rest::binary>>), do: {"", rest}

  defp skip_to_m(<<c, rest::binary>>) do
    {skipped, after_rest} = skip_to_m(rest)
    {<<c>> <> skipped, after_rest}
  end

  defp skip_to_m(""), do: {"", ""}

  # Apply an SGR parameter string (no leading `\e[` or trailing `m`).
  # Returns `{fg_or_no_change, new_effects}`.
  defp apply_sgr(fg, effects, skipped) do
    {fg_change, on, off} = parse_sgr_codes(skipped)

    new_fg =
      case fg_change do
        @no_fg_change -> fg
        nil -> nil
        rgb -> rgb
      end

    new_effects =
      if on == [] and off == [], do: effects, else: (effects -- off) ++ Enum.reverse(on)

    {new_fg, new_effects}
  end

  # Returns `{fg_change, on_atoms, off_atoms}`. fg_change is one of:
  #   `@no_fg_change` — not a colour code, leave as is
  #   `nil` — explicit reset (SGR 39)
  #   `{r,g,b}` — colour tuple
  defp parse_sgr_codes(skipped) do
    parts = String.split(skipped, ";")

    Enum.reduce(parts, {@no_fg_change, [], []}, fn part, acc ->
      classify_sgr_part(part, acc)
    end)
  end

  # Single-part SGR classifier. Returns the new accumulator tuple.
  # `acc` is `{fg_change, on_atoms, off_atoms}` from the outer reduce.
  # Extracted from `parse_sgr_codes/1` to keep that function under the
  # cyclomatic complexity cap.
  defp classify_sgr_part(part, {fg_acc, on_acc, off_acc}) do
    {new_fg, on, off} =
      case part do
        "" ->
          {:skip}

        "0" ->
          {nil, [], []}

        "39" ->
          {nil, [], []}

        p when byte_size(p) == 2 ->
          classify_short_sgr(p)

        p when is_binary(p) ->
          classify_long_sgr(p)
      end

    case new_fg do
      :skip -> {fg_acc, on_acc, off_acc}
      _ -> merge_sgr_change({new_fg, on, off}, {fg_acc, on_acc, off_acc})
    end
  end

  defp classify_short_sgr(<<c, _::binary>> = p) when c in ?0..?7 or c in ?9..?9 do
    {parse_standard_fg_code(p), [], []}
  end

  defp classify_short_sgr(p), do: classify_long_sgr(p)

  defp classify_long_sgr(part) do
    cond do
      String.starts_with?(part, "38;2;") ->
        {parse_truecolor_skip(part), [], []}

      String.starts_with?(part, "38;5;") ->
        {parse_xterm256_skip(part), [], []}

      Map.has_key?(@sgr_to_effect, part) ->
        {@no_fg_change, [Map.fetch!(@sgr_to_effect, part)], []}

      part =~ ~r/^2[2-5]$/ ->
        {@no_fg_change, [], [off_atom_for(part)]}

      true ->
        {@no_fg_change, [], []}
    end
  end

  defp merge_sgr_change({new_fg, on, off}, {fg_acc, on_acc, off_acc}) do
    fg_out = if new_fg == @no_fg_change, do: fg_acc, else: new_fg
    {fg_out, on ++ on_acc, off ++ off_acc}
  end

  defp off_atom_for("22"), do: :bold
  defp off_atom_for("23"), do: :italic
  defp off_atom_for("24"), do: :underline
  defp off_atom_for("25"), do: :blink

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

  @spec build_header_row(list(), list(integer()), Alaja.Components.Table.Config.t(), keyword()) ::
          list()
  def build_header_row(headers, widths, config, opts) do
    border_chars = config.border_chars
    border_color = config.border_color

    headers_color = Keyword.get(opts, :headers_color)
    headers_effects = Keyword.get(opts, :headers_effects, [])
    headers_align = Keyword.get(opts, :headers_align, @default_align)

    vertical = Theme.render_formatted(border_chars.vertical, border_color, config.border_effects)

    cells =
      headers
      |> Enum.with_index()
      |> Enum.map(fn {text, idx} ->
        width = Enum.at(widths, idx)
        cell_color = Theme.get_column_opts(idx, headers_color, nil)
        cell_effects = Theme.get_column_opts(idx, headers_effects, [])
        cell_align = Theme.get_column_opts(idx, headers_align, @default_align)
        aligned = Calculator.apply_alignment(to_string(text), cell_align, width, config.padding)
        Theme.render_formatted(aligned, cell_color, cell_effects)
      end)

    [
      config.offset_str,
      vertical,
      Enum.intersperse(cells, vertical),
      vertical,
      "\n"
    ]
  end

  @spec build_rows(list(), list(integer()), Alaja.Components.Table.Config.t(), keyword()) ::
          list()
  def build_rows(rows, widths, config, opts) do
    border_chars = config.border_chars
    border_color = config.border_color

    rows_color = Keyword.get(opts, :rows_color)
    rows_effects = Keyword.get(opts, :rows_effects, [])
    rows_align = Keyword.get(opts, :rows_align, @default_align)

    row_specific_opts = Alaja.Components.Table.Builder.extract_row_specific_opts(opts)

    vertical = Theme.render_formatted(border_chars.vertical, border_color, config.border_effects)

    rows_with_index = Enum.with_index(rows)

    Enum.map(rows_with_index, fn {row, row_index} ->
      {row_color, row_effects, row_align, effect_masks} =
        Alaja.Components.Table.Builder.get_row_opts(
          row_index,
          row_specific_opts,
          rows_color,
          rows_effects,
          rows_align
        )

      cells =
        row
        |> Enum.with_index()
        |> Enum.map(fn {text, idx} ->
          width = Enum.at(widths, idx, 10)
          cell_color = Theme.get_column_opts(idx, row_color, nil)
          cell_effects = cell_effects_for(idx, row_effects, effect_masks)
          cell_align = Theme.get_column_opts(idx, row_align, @default_align)
          aligned = Calculator.apply_alignment(to_string(text), cell_align, width, config.padding)
          Theme.render_formatted(aligned, cell_color, cell_effects)
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

  # Per-cell effects for `build_rows/4`: take the row-wide effect list,
  # filter it through any per-cell mask in `effect_masks`. Extracted
  # to keep the Enum.map closure shallow (credo nesting cap = 2).
  #
  # Argument order note: `Theme.get_column_opts/3` is
  # `(column_index, column_opts, default_value)`. Without the explicit
  # call below, the pipe would route `row_effects` (the column_opts)
  # into the `column_index` slot, returning `nil`/the integer index
  # and silently dropping every effect.
  defp cell_effects_for(idx, row_effects, effect_masks) do
    Theme.get_column_opts(idx, row_effects, [])
    |> List.wrap()
    |> Alaja.Components.Table.Builder.apply_effect_mask(idx, effect_masks)
  end

  @spec print_header_row(list(), list(integer()), Alaja.Components.Table.Config.t(), keyword()) ::
          :ok
  def print_header_row(headers, widths, config, opts) do
    color = Keyword.get(opts, :headers_color)
    effects = Keyword.get(opts, :headers_effects, [])
    align = Keyword.get(opts, :headers_align, @default_align)
    # Headers don't carry per-cell effect masks — the row-wide
    # effects list is applied uniformly.
    print_row_with_masks(headers, widths, color, effects, align, %{}, config)
  end

  @spec print_rows(list(), list(integer()), Alaja.Components.Table.Config.t(), keyword()) :: :ok
  def print_rows(rows, widths, config, opts) do
    rows_color = Keyword.get(opts, :rows_color)
    rows_effects = Keyword.get(opts, :rows_effects, [])
    rows_align = Keyword.get(opts, :rows_align, @default_align)
    row_specific_opts = Alaja.Components.Table.Builder.extract_row_specific_opts(opts)

    Enum.with_index(rows)
    |> Enum.each(fn {row, row_index} ->
      {color, effects, align, effect_masks} =
        Alaja.Components.Table.Builder.get_row_opts(
          row_index,
          row_specific_opts,
          rows_color,
          rows_effects,
          rows_align
        )

      print_row_with_masks(row, widths, color, effects, align, effect_masks, config)
    end)
  end

  # Print a row with per-cell effect masking. When `masks` is empty
  # (e.g. the header row), this is the same as a vanilla row print.
  # When `masks` has an entry like `%{bold: [true, false, true]}`,
  # the `bold` effect survives on cells 0 and 2 but is dropped on
  # cell 1 of this row.
  defp print_row_with_masks(row, widths, color, effects, align, masks, config) do
    filled_row = fill_row(row, length(widths))

    cells =
      filled_row
      |> Enum.with_index()
      |> Enum.map(fn {cell, i} ->
        width = Enum.at(widths, i, 0)
        cell_color = Theme.get_column_opts(i, color, nil)
        cell_effects = cell_effects_for(i, effects, masks)
        cell_align = Theme.get_column_opts(i, align, @default_align)

        aligned_str =
          Calculator.apply_alignment(to_string(cell), cell_align, width, config.padding)

        Theme.render_formatted(aligned_str, cell_color, cell_effects)
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

  @spec fill_row(list(), integer()) :: list()
  def fill_row(row, target_length) when is_list(row) and length(row) >= target_length, do: row

  def fill_row(row, target_length) when is_list(row),
    do: row ++ List.duplicate("", target_length - length(row))

  def fill_row(_, _), do: []
end
