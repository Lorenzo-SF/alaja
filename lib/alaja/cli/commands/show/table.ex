# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Alaja.CLI.Commands.Show.Table do
  alias Alaja.CLI.Commands.Base, as: Base

  # Delegate common helpers to Base
  defdelegate parse_color(arg), to: Base, as: :parse_color, arity: 1
  defdelegate parse_color_list(arg), to: Base, as: :parse_color_list, arity: 1
  defdelegate parse_align(arg), to: Base, as: :parse_align, arity: 1
  defdelegate parse_align_list(arg), to: Base, as: :parse_align_list, arity: 1
  defdelegate parse_effects(arg), to: Base, as: :parse_effects, arity: 1
  defdelegate parse_effects_list(arg), to: Base, as: :parse_effects_list, arity: 1
  defdelegate term_width(), to: Base, as: :term_width, arity: 0
  defdelegate apply_align(line, align), to: Base, as: :apply_align, arity: 2
  defdelegate parse_border_opt(s), to: Base, as: :parse_border_opt, arity: 1
  @moduledoc "`alaja table` — Display formatted tables."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Table, as: TableComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Table",
    subtitle: "Display formatted tables with borders and styling",
    usage:
      "alaja table --headers 'col1,col2,col3' --rows 'a,b,c;d,e,f' [--border S] [--padding N] [--border-color C] [--border-effects E,E] [--headers-color C] [--headers-align left|center|right] [--headers-effects E,E] [--rows-color C] [--rows-align left|center|right] [--rows-effects E,E] [--table-align left|center|right]",
    description: """
    Renders a multi-column table. Headers and rows are passed as
    semicolon-separated lists; column-aligned values are accepted.
    """,
    options: [
      {:headers, :string, nil, "Comma-separated header titles"},
      {:rows, :keep, nil, "Semicolon-separated rows; each row is comma-separated cells"},
      {:border, :string, "rounded", "Border style (normal, rounded, double, single, bold, none)"},
      {:padding, :integer, 1, "Cell padding"},
      {:border_color, :string, nil, "Border color"},
      {:border_effects, :string, nil, "Comma-separated border effects (bold, dim, etc.)"},
      {:headers_color, :string, nil, "Header cell color"},
      {:headers_align, :string, nil, "Header cell alignment"},
      {:headers_effects, :string, nil, "Header cell effects"},
      {:rows_color, :string, nil, "Body row color"},
      {:rows_align, :string, nil, "Body row alignment"},
      {:rows_effects, :string, nil, "Body row effects"},
      {:table_align, :string, nil, "Default alignment for all cells"}
    ],
    examples: [
      {"Tabla con bordes redondeados", "alaja table --headers name,status --rows \"api,ok\" \"web,ok\" --border rounded --headers-color cyan"},
      {"Tabla simple", "alaja table --headers a,b,c --rows \"1,2,3\" \"4,5,6\""}
    ]
  ]

  @doc """
  Runs the table command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    # Parse standard switches first
    {opts, _, _invalid} =
      OptionParser.parse(rest,
        switches: [
          headers: :string,
          rows: :keep,
          border: :string,
          padding: :integer,
          border_color: :string,
          border_effects: :string,
          headers_color: :string,
          headers_align: :string,
          headers_effects: :string,
          rows_color: :string,
          rows_align: :string,
          rows_effects: :string,
          table_align: :string
        ]
      )

    # Collect per-row args (--row-<N>-color, --row-<N>-align, --row-<N>-effect)
    # from raw args, including any that OptionParser flagged as invalid
    per_row_opts = parse_per_row_args(rest)
    opts = Keyword.merge(opts, per_row_opts)

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      headers_str = Keyword.get(opts, :headers, "")
      rows_opts = Keyword.get_values(opts, :rows)

      if headers_str == "" and rows_opts == [] do
        help()
      else
        render(opts, global)
      end
    end
  end

  defp render(opts, global) do
    headers = build_headers(Keyword.get(opts, :headers, ""))
    rows = build_rows(Keyword.get_values(opts, :rows))
    table_opts = build_table_opts(opts, global)

    rendered = TableComp.render([headers | rows], table_opts)
    Printer.print_raw(rendered, printer_opts(global))
  end

  @spec build_headers(String.t()) :: [String.t()]
  defp build_headers(""), do: []

  defp build_headers(headers_str) do
    String.split(headers_str, ";")
  end

  @spec build_rows([String.t()]) :: [[String.t()]]
  defp build_rows([]), do: []

  defp build_rows(rows_opts) do
    rows_opts
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn r -> String.split(r, "|") end)
    |> Enum.map(fn r -> String.split(r, ";") end)
  end

  @spec build_table_opts(keyword(), GlobalOpts.t()) :: keyword()
  defp build_table_opts(opts, global) do
    border = parse_border_opt(Keyword.get(opts, :border, "normal"))
    padding = Keyword.get(opts, :padding, 1)

    per_row_opts = build_per_row_opts(opts)

    [
      table_border: border,
      table_align: table_align(opts, global),
      align: global.align,
      padding: padding,
      border_color: parse_color(Keyword.get(opts, :border_color)),
      border_effects: parse_effects(Keyword.get(opts, :border_effects)),
      headers_color: parse_color_list(Keyword.get(opts, :headers_color)),
      headers_align: parse_align_list(Keyword.get(opts, :headers_align)),
      headers_effects: parse_effects_list(Keyword.get(opts, :headers_effects)),
      rows_color: parse_color_list(Keyword.get(opts, :rows_color)),
      rows_align: parse_align_list(Keyword.get(opts, :rows_align)),
      rows_effects: parse_effects_list(Keyword.get(opts, :rows_effects))
    ]
    |> Keyword.merge(per_row_opts)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  # Parse --row-<N>-color, --row-<N>-align, --row-<N>-effect from raw args
  # Converts to backend format: rows_<N-1>_color, rows_<N-1>_align, rows_<N-1>_effects
  # Row numbers in CLI are 1-indexed; backend uses 0-indexed.
  # Supports both --row-N-color VALUE and --row-N-color=VALUE forms.
  @spec parse_per_row_args([String.t()]) :: keyword()
  defp parse_per_row_args(args) do
    args
    |> expand_row_args()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(&row_flag?/1)
    |> Enum.map(&parse_row_flag/1)
    |> Enum.reject(&is_nil/1)
  end

  # Splits --row-N-xxx=VALUE into two-element list ["--row-N-xxx", "VALUE"]
  defp expand_row_args(args) do
    Enum.flat_map(args, fn
      arg when is_binary(arg) ->
        if String.starts_with?(arg, "--row-") and String.contains?(arg, "=") do
          String.split(arg, "=", parts: 2)
        else
          [arg]
        end

      other ->
        [other]
    end)
  end

  defp row_flag?([flag, _val]) when is_binary(flag) do
    String.starts_with?(flag, "--row-") and
      (String.ends_with?(flag, "-color") or
         String.ends_with?(flag, "-align") or
         String.ends_with?(flag, "-effect"))
  end

  defp row_flag?(_), do: false

  defp parse_row_flag([flag, val]) do
    rest = String.trim_leading(flag, "--row-")
    parts = String.split(rest, "-", parts: 2)

    with [row_str, suffix] when suffix in ~w(color align effect) <- parts,
         {row_num, ""} when row_num > 0 <- Integer.parse(row_str) do
      build_per_row_key(row_num - 1, suffix, val)
    else
      _ -> nil
    end
  end

  # Atoms are deterministic: bounded row numbers (0..99 max) + 3 known suffixes.
  # Using String.to_atom/1 is safe here — cannot exhaust the atom table.
  defp build_per_row_key(backend_row, suffix, val),
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    do: {String.to_atom("rows_#{backend_row}_#{suffix}"), val}

  # Convert per-row parsed opts to their parsed values (color, align, effect)
  @spec build_per_row_opts(keyword()) :: keyword()
  defp build_per_row_opts(opts) do
    opts
    |> Enum.filter(fn {key, _val} ->
      key_str = Atom.to_string(key)

      String.starts_with?(key_str, "rows_") and
        (String.ends_with?(key_str, "_color") or
           String.ends_with?(key_str, "_align") or
           String.ends_with?(key_str, "_effects"))
    end)
    |> Enum.map(fn
      {key, val} when is_binary(val) ->
        cond do
          String.ends_with?(Atom.to_string(key), "_color") ->
            {key, Base.parse_color_list(val)}

          String.ends_with?(Atom.to_string(key), "_align") ->
            {key, Base.parse_align_list(val)}

          String.ends_with?(Atom.to_string(key), "_effects") ->
            {key, Base.parse_effects_list(val)}

          true ->
            {key, val}
        end

      {key, val} ->
        {key, val}
    end)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  @spec table_align(keyword(), GlobalOpts.t()) :: atom()
  defp table_align(opts, global) do
    if global.box do
      :left
    else
      Base.parse_align(Keyword.get(opts, :table_align)) || global.align
    end
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc """
  Prints help for the table command.
  """
  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
