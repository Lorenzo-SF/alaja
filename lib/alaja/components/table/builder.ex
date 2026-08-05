defmodule Alaja.Components.Table.Builder do
  @moduledoc false

  alias Alaja.CLI.Pagination
  alias Alaja.Components.Table
  alias Alaja.Components.Table.{Borders, Calculator, Page, Renderer, Theme}

  @default_border_style :normal
  @default_padding 1
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
    data_fun = Keyword.get(opts, :data_fun)

    cond do
      is_function(data_fun, 1) and is_integer(page_size) and page_size > 0 ->
        print_paginated(headers, rows, page_size, opts)

      data_fun ->
        raise ArgumentError,
              "Table with :data_fun requires a positive :page_size. " <>
                "Contract: fn(%{page_size: pos_integer(), page: non_neg_integer(), " <>
                "search: String.t()}) :: Alaja.Components.Table.Page.t()"

      page_size && is_integer(page_size) && page_size > 0 && length(rows) > page_size ->
        print_paginated(headers, rows, page_size, opts)

      true ->
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

  @spec print_paginated(list(), list(), pos_integer(), keyword()) :: :ok
  defp print_paginated(headers, rows, page_size, opts) do
    data_fun = Keyword.get(opts, :data_fun)

    IO.write(Alaja.ANSI.hide_cursor())

    try do
      if Pagination.tty?() do
        IO.write(Alaja.ANSI.save_cursor())
        paginated_loop(headers, rows, page_size, opts, data_fun, %{page: 0, search: ""})
      else
        # No TTY: no interaction possible. Print everything when the
        # source is a plain list, otherwise the first page only.
        page = fetch_page(headers, rows, page_size, opts, data_fun, 0, "")
        render_page(page, opts)
      end
    after
      IO.write(Alaja.ANSI.show_cursor())
    end
  end

  @spec paginated_loop(list(), list(), pos_integer(), keyword(), function() | nil, map()) :: :ok
  defp paginated_loop(headers, rows, page_size, opts, data_fun, state) do
    page = fetch_page(headers, rows, page_size, opts, data_fun, state.page, state.search)
    state = %{state | page: page.page}

    repaint_page(page, opts, state.search)

    case Pagination.read_key() do
      :quit ->
        :ok

      key ->
        case apply_key(key, state) do
          :quit ->
            :ok

          new_state ->
            paginated_loop(headers, rows, page_size, opts, data_fun, new_state)
        end
    end
  end

  @doc """
  Applies a key press to the paginator state.

  Pure function (no I/O). Keys:

    * `:right` — next page
    * `:left` — previous page
    * `:backspace` — remove the last search character
    * `:esc`, `"q"` — quit
    * alphanumeric characters — appended to the search text (and the
      page resets to the first one)

  Returns `:quit` or the new state map (`%{page: int, search: string}`).
  """
  @spec apply_key(term(), map()) :: :quit | map()
  def apply_key(key, state) do
    case key do
      :esc -> :quit
      "q" -> :quit
      :right -> %{state | page: state.page + 1}
      :left -> %{state | page: max(state.page - 1, 0)}
      :backspace -> %{state | search: String.slice(state.search, 0..-2//1) || ""}
      :enter -> state
      char when is_binary(char) ->
        if String.match?(char, ~r/^[[:alnum:]]$/),
          do: %{state | search: state.search <> char, page: 0},
          else: state

      _ ->
        state
    end
  end

  @doc """
  Builds the page of rows for the given page number and search text.

  Pure function. With `:data_fun` the function is called with the
  request contract and its result trusted (after an impossible-result
  safety retry); otherwise rows are filtered with a case-insensitive
  "like" match over every cell and sliced locally.
  """
  @spec build_page(list(), list(), pos_integer(), function() | nil, non_neg_integer(), String.t()) ::
          Page.t()
  def build_page(headers, rows, page_size, data_fun, page, search) do
    if is_function(data_fun, 1) do
      fetch_from_fun(data_fun, page_size, page, search)
    else
      slice_page(headers, rows, page_size, page, search)
    end
  end

  @doc """
  Case-insensitive "like" search over every cell of a row.
  """
  @spec row_matches?(list(), String.t()) :: boolean()
  def row_matches?(row, search) do
    needle = String.downcase(search)

    Enum.any?(row, fn cell ->
      is_binary(cell) and String.contains?(String.downcase(cell), needle)
    end)
  end

  @spec fetch_page(list(), list(), pos_integer(), keyword(), function() | nil, non_neg_integer(), String.t()) ::
          Page.t()
  defp fetch_page(headers, rows, page_size, _opts, data_fun, page, search) do
    build_page(headers, rows, page_size, data_fun, page, search)
  end

  @spec fetch_from_fun(function(), pos_integer(), non_neg_integer(), String.t()) :: Page.t()
  defp fetch_from_fun(data_fun, page_size, page, search) do
    case data_fun.(%{page_size: page_size, page: page, search: search}) do
      %Page{} = result ->
        # Impossible result (requested page beyond the reported total):
        # fall back to the first page with the same page size.
        if result.total_rows > 0 and result.page * page_size >= result.total_rows and
             result.page != 0 do
          data_fun.(%{page_size: page_size, page: 0, search: search})
        else
          result
        end

        other ->
          raise ArgumentError,
                "Table :data_fun must return an Alaja.Components.Table.Page.t(), got: " <>
                  inspect(other)
      end
  end

  @spec slice_page(list(), list(), pos_integer(), non_neg_integer(), String.t()) :: Page.t()
  defp slice_page(headers, rows, page_size, page, search) do
    {headers, rows} = normalize_data(headers, rows)

    filtered =
      if search == "", do: rows, else: Enum.filter(rows, &row_matches?(&1, search))

    total = length(filtered)
    page = Pagination.clamp_page(page, page_size, total)

    %Page{
      headers: headers,
      rows: Enum.slice(filtered, page * page_size, page_size),
      page: page,
      total_pages: Pagination.total_pages(total, page_size),
      total_rows: total
    }
  end

  @spec render_page(Page.t(), keyword()) :: :ok
  defp render_page(%Page{} = page, opts) do
    {headers, rows} = normalize_data(page.headers, page.rows)
    column_widths = Calculator.calculate_column_widths([headers | rows])
    config = build_config(opts, column_widths)
    do_print_table(headers, rows, column_widths, config, opts)
    :ok
  end

  defp repaint_page(page, opts, search) do
    IO.write([Alaja.ANSI.restore_cursor(), Alaja.ANSI.clear_line_down()])

    page_text =
      Table.render_iodata(
        [headers: page.headers, rows: page.rows],
        opts
      )

    search_part = if search == "", do: "", else: "  search: '#{search}'"
    nav = "Page #{page.page + 1}/#{page.total_pages} | rows: #{page.total_rows}#{search_part}"
    hint = " | ←→ navigate   type to search   backspace delete   q/esc quit"

    # Raw-mode-safe write: `\n` alone would not return the carriage on a
    # terminal in raw mode (ONLCR is off), so every newline becomes `\r\n`.
    content =
      [page_text, "\r\n", "\e[2m", nav, hint, "\e[0m", "\r\n"]
      |> IO.iodata_to_binary()
      |> String.replace("\n", "\r\n")

    IO.write(content)
    :ok
  end
end
