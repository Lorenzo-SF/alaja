defmodule Alaja.Components.Table.Builder do
  @moduledoc false

  alias Alaja.Components.Table.{Borders, Calculator, Renderer, Theme}

  @default_border_style :normal
  @default_padding 1
  @default_align :left
  @default_table_align :left

  @spec extract_headers_rows(list()) :: {list(), list()}
  def extract_headers_rows([headers | rows]) when is_list(headers), do: {headers, rows}
  def extract_headers_rows(_), do: {[], []}

  @spec extract_table_opts(list()) :: keyword()
  def extract_table_opts(data) when is_list(data) and not is_tuple(hd(data)) do
    Keyword.take(data, [:border_color, :border_effects, :padding, :table_align, :table_border])
  end

  def extract_table_opts(data), do: Keyword.drop(data, [:headers, :rows])

  @spec normalize_data(list() | nil, list()) :: {list(), list()}
  def normalize_data(headers, rows) do
    num_header_cols = if headers != [] and headers != nil, do: length(headers), else: 0

    rows =
      if num_header_cols > 0 do
        Enum.map(rows, fn row -> Enum.take(row, num_header_cols) end)
      else
        rows
      end

    {headers, rows}
  end

  @spec build_config(keyword(), list(integer())) :: Alaja.Components.Table.Config.t()
  def build_config(opts, column_widths) do
    border_style = Keyword.get(opts, :table_border, @default_border_style)
    border_chars = Borders.get_border_chars(border_style, Keyword.get(opts, :table_border_custom))
    padding = Keyword.get(opts, :padding, @default_padding)
    table_align = Keyword.get(opts, :table_align, Keyword.get(opts, :align, @default_table_align))
    table_width = Calculator.calculate_table_width(column_widths, padding)
    offset_spaces = Calculator.get_table_offset(table_width, table_align)
    offset_str = String.duplicate(" ", offset_spaces)

    border_color = Keyword.get(opts, :border_color)
    border_effects = Keyword.get(opts, :border_effects, [])

    rendered_vertical =
      if border_style != :none do
        Theme.render_formatted(border_chars.vertical, border_color, border_effects)
      else
        ""
      end

    horizontal = border_chars.horizontal

    horizontal_segments =
      if horizontal != "" do
        unique_widths = Enum.uniq(column_widths)

        segments_cache =
          Enum.into(unique_widths, %{}, fn w ->
            segment = String.duplicate(horizontal, w + padding * 2 + 4)

            {w, Theme.render_formatted(segment, border_color, border_effects)}
          end)

        Enum.map(column_widths, fn w -> Map.get(segments_cache, w) end)
      else
        Enum.map(column_widths, fn _ -> "" end)
      end

    %Alaja.Components.Table.Config{
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

  @spec extract_row_specific_opts(keyword()) :: map()
  def extract_row_specific_opts(opts) do
    opts
    |> Enum.filter(fn {key, _value} ->
      key_string = Atom.to_string(key)

      String.starts_with?(key_string, "rows") and
        (String.contains?(key_string, "color") or
           String.contains?(key_string, "effects") or
           String.contains?(key_string, "align"))
    end)
    |> Enum.map(fn {key, value} ->
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

  @spec get_row_opts(integer(), map(), term(), list(), atom()) :: {term(), list(), atom()}
  def get_row_opts(row_index, row_specific_opts, default_color, default_effects, default_align) do
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

  @spec print_with_headers(list() | nil, list(), keyword()) :: :ok
  def print_with_headers(headers, rows, opts) do
    page_size = Keyword.get(opts, :page_size)

    if page_size && is_integer(page_size) && page_size > 0 && length(rows) > page_size do
      print_paginated(headers, rows, page_size, opts)
    else
      {headers, rows} = normalize_data(headers, rows)
      column_widths = Calculator.calculate_column_widths([headers | rows])
      config = build_config(opts, column_widths)
      do_print_table(headers, rows, column_widths, config, opts)
    end
  end

  @spec do_print_table(
          list(),
          list(),
          list(integer()),
          Alaja.Components.Table.Config.t(),
          keyword()
        ) ::
          :ok
  def do_print_table(headers, rows, widths, config, opts) do
    if config.border_style != :none, do: Borders.print_top_border(widths, config)

    if headers != [] and headers != nil do
      Renderer.print_header_row(headers, widths, config, opts)

      if rows != [], do: Borders.print_header_separator(widths, config)
    end

    Renderer.print_rows(rows, widths, config, opts)

    if config.border_style != :none, do: Borders.print_bottom_border(widths, config)

    :ok
  end

  @spec print_paginated(list(), list(), integer(), keyword()) :: :ok
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
    column_widths = Calculator.calculate_column_widths([headers | page_rows])
    config = build_config(opts, column_widths)

    clear_screen_area()
    do_print_table(headers, page_rows, column_widths, config, opts)

    nav =
      "Page #{page + 1}/#{total_pages} | n=next  p=prev  f=first  l=last  g=goto  q=quit"

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

  @spec handle_navigation(String.t(), integer(), integer()) :: integer() | :quit
  def handle_navigation("n", page, total_pages), do: min(page + 1, total_pages - 1)
  def handle_navigation("p", page, _total_pages), do: max(page - 1, 0)
  def handle_navigation("f", _page, _total_pages), do: 0
  def handle_navigation("l", _page, total_pages), do: total_pages - 1
  def handle_navigation("g", _page, total_pages), do: goto_page(total_pages)
  def handle_navigation("q", _page, _total_pages), do: :quit
  def handle_navigation("\e", _page, _total_pages), do: :quit
  def handle_navigation(_key, page, _total_pages), do: page

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
    IO.write(Alaja.ANSI.clear_screen())
    IO.write(Alaja.ANSI.cursor_home())
  end
end
