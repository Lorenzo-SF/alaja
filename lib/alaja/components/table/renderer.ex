defmodule Alaja.Components.Table.Renderer do
  @moduledoc false

  alias Alaja.Buffer
  alias Alaja.Components.Table.{Borders, Calculator, Theme}

  @default_align :left
  @no_fg_change :"$no_fg_change"

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
        |> Enum.reduce({buf, 0}, fn {{char, fg}, _idx}, {b, x} ->
          {Buffer.put(b, x, y, char, fg), x + 1}
        end)

      final
    end)
  end

  defp parse_line(line) when is_binary(line) do
    {cells, _fg, _rest} = parse_chars(line, [], nil)
    Enum.reverse(cells)
  end

  defp parse_chars("", acc, fg), do: {acc, fg, ""}

  defp parse_chars(<<0x1B, "[0m", rest::binary>>, acc, _fg) do
    parse_chars(rest, acc, nil)
  end

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

  defp parse_chars(<<0x1B, "[m", rest::binary>>, acc, fg) do
    parse_chars(rest, acc, fg)
  end

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

  defp apply_sgr(_acc, fg, skipped) do
    case parse_fg_sgr(skipped) do
      @no_fg_change -> fg
      nil -> nil
      rgb -> rgb
    end
  end

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
      {row_color, row_effects, row_align} =
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
          cell_effects = Theme.get_column_opts(idx, row_effects, [])
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

  @spec print_header_row(list(), list(integer()), Alaja.Components.Table.Config.t(), keyword()) ::
          :ok
  def print_header_row(headers, widths, config, opts) do
    color = Keyword.get(opts, :headers_color)
    effects = Keyword.get(opts, :headers_effects, [])
    align = Keyword.get(opts, :headers_align, @default_align)
    print_row(headers, widths, color, effects, align, config)
  end

  @spec print_rows(list(), list(integer()), Alaja.Components.Table.Config.t(), keyword()) :: :ok
  def print_rows(rows, widths, config, opts) do
    rows_color = Keyword.get(opts, :rows_color)
    rows_effects = Keyword.get(opts, :rows_effects, [])
    rows_align = Keyword.get(opts, :rows_align, @default_align)
    row_specific_opts = Alaja.Components.Table.Builder.extract_row_specific_opts(opts)

    Enum.with_index(rows)
    |> Enum.each(fn {row, row_index} ->
      {color, effects, align} =
        Alaja.Components.Table.Builder.get_row_opts(
          row_index,
          row_specific_opts,
          rows_color,
          rows_effects,
          rows_align
        )

      print_row(row, widths, color, effects, align, config)
    end)
  end

  @spec print_row(
          list(),
          list(integer()),
          term(),
          list(),
          atom(),
          Alaja.Components.Table.Config.t()
        ) ::
          :ok
  def print_row(row, widths, color, effects, align, config) do
    filled_row = fill_row(row, length(widths))

    cells =
      filled_row
      |> Enum.with_index()
      |> Enum.map(fn {cell, i} ->
        width = Enum.at(widths, i, 0)
        cell_color = Theme.get_column_opts(i, color, nil)
        cell_effects = Theme.get_column_opts(i, effects, [])
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
