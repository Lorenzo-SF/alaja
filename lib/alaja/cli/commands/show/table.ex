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
      "alaja table --headers 'col1;col2;col3' --rows 'a;b;c\\;d' [--border S] [--padding N] [--border-color C] [--border-effects E,E] [--headers-color C] [--headers-align left|center|right] [--headers-effects E,E] [--rows-color C] [--rows-align left|center|right] [--rows-effects E,E] [--table-align left|center|right] [--row-N-color C] [--row-N-align A] [--row-N-effects E,E]",
    description: """
    Renders a multi-column table.

    Within `--headers`, columns are separated by `;`. Within `--rows`,
    cells are also separated by `;` and rows are either separated by
    `;;` (a double `;`) or by repeating `--rows` once per row.

    To include a literal `;` inside a cell, escape it as `\\;`. To
    include a literal `\\` use `\\\\`.

    Per-row styling uses `--row-N-{color,align,effects}` where N is
    1-indexed. Both `effect` (legacy) and `effects` (canonical) are
    accepted.
    """,
    options: [
      {:headers, :string, nil, "Semicolon-separated header titles"},
      {:rows, :keep, nil,
       "Rows: `;` between cells, `;;` between rows within one arg, or repeat --rows per row. Escape `;` as `\\;`."},
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
      {"Simple grid", "alaja table --headers 'name;status' --rows 'api;OK;;db;WARN'"},
      {"Cell with literal semicolon",
       "alaja table --headers 'name;note' --rows 'api;ok\\;on-call'"},
      {"Custom border", "alaja table --headers 'a;b;c' --rows '1;2;3;;4;5;6' --border double"},
      {"No border",
       "alaja table --headers 'key;value' --rows 'host;db.local;;port;5432' --border none"},
      {"Coloured headers",
       "alaja table --headers 'name;status;env' --rows 'api;OK;prod;;web,WARN,stg' --headers-color cyan --headers-effects bold"},
      {"Right-aligned numbers",
       "alaja table --headers 'q1;q2;q3;q4' --rows 'sales;100;150;200;90' --table-align right"},
      {"Per-row styling",
       "alaja table --headers 'service;status' --rows 'api;OK;;db;WARN' --row-1-color green --row-2-color yellow"},
      {"Health dashboard",
       "alaja table --headers 'service;status;uptime' --rows 'api;OK;12d;;db;WARN;2h;;cache;OK;30d' --border rounded --padding 2"}
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

    if global.help do
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
    headers_str
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  @spec build_rows([String.t()]) :: [[String.t()]]
  defp build_rows([]), do: []

  # Rows use `;` to separate cells and `;;` to separate rows within a
  # single `--rows` argument, OR repeated `--rows` once per row.
  # Literal `;` inside a cell is escaped as `\;` and unescaped here.
  #
  # To make the split escape-aware we replace `\;` with a placeholder
  # *before* splitting, then restore the literal `;` after the split.
  # Same trick for `\\` so a backslash can be part of a cell content.
  defp build_rows(rows_opts) do
    rows_opts
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn arg ->
      arg
      |> escape_for_split(";")
      |> String.split(";;")
    end)
    |> Enum.map(fn r ->
      r
      |> escape_for_split(";")
      |> String.split(";")
      |> Enum.map(&unescape_after_split/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end)
    |> Enum.reject(&(&1 == []))
  end

  # `sep` (one char) inside a cell is escaped as `\\<sep>` in user
  # input. Replace the escaped form with a placeholder before splitting.
  defp escape_for_split(text, sep) do
    String.replace(text, "\\" <> sep, "\x00")
  end

  defp unescape_after_split(cell) do
    cell
    |> String.replace("\\\\", "\x01")
    |> String.replace("\x00", sep_for_restore())
    |> String.replace("\x01", "\\")
  end

  # `;` is the cell separator; `;;` is the row separator. After we split
  # cells, only `;` should reappear inside a cell value.
  defp sep_for_restore, do: ";"

  @spec build_table_opts(keyword(), GlobalOpts.t()) :: keyword()
  defp build_table_opts(opts, global) do
    border = parse_border_opt(Keyword.get(opts, :border, "rounded"))
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

  # Accepts `--row-N-<X>` where N is a positive integer and `<X>` is
  # at least one character. Covers colour/align/effects plus the new
  # per-cell effect-name masks (bold, italic, ...).
  defp row_flag?([flag, _val]) when is_binary(flag) do
    valid_row_flag?(flag)
  end

  defp row_flag?(_), do: false

  defp valid_row_flag?("--row-" <> rest), do: row_num_suffix_valid?(rest)
  defp valid_row_flag?(_), do: false

  defp row_num_suffix_valid?(rest) do
    case String.split(rest, "-", parts: 2) do
      [num, suffix] -> positive_int?(num) and suffix != ""
      _ -> false
    end
  end

  defp positive_int?(num_str) do
    case Integer.parse(num_str) do
      {n, ""} when n > 0 -> true
      _ -> false
    end
  end

  # Per-row flag suffixes the parser recognises explicitly:
  #   `color`, `align`, `effects` (and the legacy singular `effect`).
  # Anything else is treated as an effect-name mask — `--row-N-bold`,
  # `--row-N-italic`, `--row-N-underline`, ... — and stored under
  # `rows_N_<name>`. The Builder picks those up per-cell.
  @row_known_suffixes ~w(color align effects effect)

  defp parse_row_flag([flag, val]) do
    rest = String.trim_leading(flag, "--row-")
    parts = String.split(rest, "-", parts: 2)

    with [row_str, suffix] <- parts,
         {row_num, ""} when row_num > 0 <- Integer.parse(row_str) do
      normalised =
        cond do
          suffix == "effect" -> "effects"
          suffix in @row_known_suffixes -> suffix
          true -> suffix
        end

      build_per_row_key(row_num - 1, normalised, val)
    else
      _ -> nil
    end
  end

  # Atoms are deterministic: bounded row numbers (0..99 max) + suffix.
  # Using String.to_atom/1 is safe here — cannot exhaust the atom table.
  defp build_per_row_key(backend_row, suffix, val),
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    do: {String.to_atom("rows_#{backend_row}_#{suffix}"), val}

  # Convert per-row parsed opts to their parsed values (color, align, effect)
  @spec build_per_row_opts(keyword()) :: keyword()
  defp build_per_row_opts(opts) do
    opts
    |> Enum.filter(&per_row_opt?/1)
    |> Enum.map(&parse_per_row_value/1)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  # A per-row opt key has the shape `rows_<N>_<suffix>`. The suffix
  # is one of the known keys (color / align / effects) or one of the
  # effects we accept as a per-cell mask (bold / italic / ...).
  defp per_row_opt?({key, _val}) do
    key_str = Atom.to_string(key)
    per_row_key?(key_str)
  end

  defp per_row_key?(key_str) do
    String.starts_with?(key_str, "rows_") and per_row_suffix?(key_str)
  end

  defp per_row_suffix?(key_str) do
    @row_per_row_suffixes
    |> Enum.any?(fn suffix -> String.ends_with?(key_str, suffix) end)
  end

  @row_per_row_suffixes [
    "_color",
    "_align",
    "_effects",
    "_bold",
    "_italic",
    "_underline",
    "_dim",
    "_blink",
    "_reverse",
    "_hidden",
    "_strikethrough"
  ]

  defp parse_per_row_value({key, val} = pair) when is_binary(val) do
    {key, parse_value_for_key(key, val)}
  end

  defp parse_per_row_value(pair), do: pair

  defp parse_value_for_key(key, val) do
    cond do
      color_key?(key) -> Base.parse_cell_color_list(val)
      String.ends_with?(Atom.to_string(key), "_align") -> Base.parse_align_list(val)
      String.ends_with?(Atom.to_string(key), "_effects") -> Base.parse_effects_list(val)
      true -> parse_boolean_mask(val)
    end
  end

  defp color_key?(key), do: String.ends_with?(Atom.to_string(key), "_color")

  # Parse a `;`-separated list of `true`/`false`/`1`/`0` values into
  # a list of booleans. Anything that doesn't parse becomes `false`
  # so a typo silently opts the cell out of the effect instead of
  # aborting the whole command.
  defp parse_boolean_mask(nil), do: nil

  defp parse_boolean_mask(str) when is_binary(str) do
    str
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&truthy?/1)
  end

  defp parse_boolean_mask(_), do: nil

  defp truthy?("true"), do: true
  defp truthy?("1"), do: true
  defp truthy?("yes"), do: true
  defp truthy?("on"), do: true
  defp truthy?(_), do: false

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
