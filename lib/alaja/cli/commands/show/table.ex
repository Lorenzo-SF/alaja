# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Alaja.CLI.Commands.Show.Table do
  @moduledoc "`alaja table` — Display formatted tables."

  alias Alaja.CLI.{GlobalOpts, Parser}
  alias Alaja.Components.{Header, Separator}
  alias Alaja.Components.Table, as: TableComp

  alias Alaja.Printer

  @doc """
  Runs the table command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _, _} =
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
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  @spec table_align(keyword(), GlobalOpts.t()) :: atom()
  defp table_align(opts, global) do
    if global.box do
      :left
    else
      parse_align(Keyword.get(opts, :table_align)) || global.align
    end
  end

  @spec parse_border_opt(String.t()) :: atom()
  defp parse_border_opt(s) do
    case Alaja.Helpers.safe_string_to_atom(s) do
      {:ok, atom} -> atom
      {:error, _} -> :normal
    end
  end

  defp parse_color(nil), do: nil
  defp parse_color(s), do: Parser.parse_color_opt(s)

  defp parse_color_list(nil), do: nil

  defp parse_color_list(s) do
    case Parser.parse_color_list(s) do
      {:ok, list} ->
        list

      {:error, msg} ->
        IO.puts(:stderr, "Color list error: #{msg}")
        nil
    end
  end

  defp parse_align(nil), do: nil

  defp parse_align(s) when is_binary(s) do
    case Alaja.Helpers.safe_string_to_atom(s) do
      {:ok, atom} -> atom
      {:error, _} -> nil
    end
  end

  defp parse_align(a), do: a

  defp parse_align_list(nil), do: nil

  defp parse_align_list(s) when is_binary(s) do
    s
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn s ->
      case Alaja.Helpers.safe_string_to_atom(s) do
        {:ok, atom} -> atom
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_effects(nil), do: nil

  defp parse_effects(s) when is_binary(s) do
    s
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn s ->
      case Alaja.Helpers.safe_string_to_atom(s) do
        {:ok, atom} -> atom
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_effects_list(nil), do: nil

  defp parse_effects_list(s) when is_binary(s) do
    s
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn s ->
      case Alaja.Helpers.safe_string_to_atom(s) do
        {:ok, atom} -> atom
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc """
  Prints help for the table command.
  """
  @spec help() :: :ok
  def help do
    Header.print("Alaja Table",
      subtitle: "Display formatted tables with borders and styling",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display a formatted table with optional borders, per-cell styling,")
    IO.puts("  colors, alignment, and effects. Supports headers and multiple rows.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja table --headers \"H1;H2;H3\" --rows \"A;B;C\" [options]")
    IO.puts("  alaja table --headers \"H1;H2\" --rows \"A;B\" --rows \"C;D\" [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    TableComp.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["--headers LIST", "No", "Column headers, semicolon-separated (e.g.: \"Name;Age;City\")"],
        [
          "--rows LIST",
          "No",
          "Table rows. Semicolon-separated values, pipe-separated for multiple rows. Repeatable flag."
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("TABLE OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    TableComp.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        [
          "--border TYPE",
          "string",
          "normal, rounded, double, single, none",
          "normal",
          "Border style around the table"
        ],
        ["--padding N", "integer", "0+", "1", "Cell padding (spaces inside cells)"],
        ["--border-color COLOR", "string", "Any color format", "", "Color of the table border"],
        [
          "--border-effects EFFECTS",
          "string",
          "Comma-separated: bold, underline, italic",
          "",
          "Text effects for table borders"
        ],
        [
          "--table-align TYPE",
          "string",
          "left, center, right",
          "left",
          "Alignment of the entire table block"
        ],
        [
          "--headers-color COLORS",
          "string",
          "Semicolon-separated colors",
          "",
          "Color(s) for header text. One color applies to all; multiple colors apply per column."
        ],
        [
          "--headers-align ALIGNS",
          "string",
          "Comma-separated: left, center, right",
          "",
          "Alignment per header column"
        ],
        [
          "--headers-effects EFFECTS",
          "string",
          "Comma-separated: bold, underline, italic",
          "",
          "Text effects for headers"
        ],
        [
          "--rows-color COLORS",
          "string",
          "Semicolon-separated colors",
          "",
          "Color(s) for row text. One color applies to all rows; multiple colors apply per column."
        ],
        [
          "--rows-align ALIGNS",
          "string",
          "Comma-separated: left, center, right",
          "",
          "Alignment per row column"
        ],
        [
          "--rows-effects EFFECTS",
          "string",
          "Comma-separated: bold, underline, italic",
          "",
          "Text effects for rows"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("GLOBAL OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    TableComp.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--raw", "boolean", "", "false", "Print at raw coordinates"],
        ["--pos-x N", "integer", "0+", "0", "X coordinate (with --raw)"],
        ["--pos-y N", "integer", "0+", "0", "Y coordinate (with --raw)"],
        ["--verbose", "boolean", "", "false", "Return raw ANSI string instead of printing"],
        ["--box", "boolean", "", "false", "Wrap output in a bordered box"],
        ["--box-title TEXT", "string", "", "", "Box title (requires --box)"],
        [
          "--box-border TYPE",
          "string",
          "rounded, single, double, bold, none",
          "rounded",
          "Border style (requires --box)"
        ],
        ["--box-color COLOR", "string", "Any color format", "", "Border color (requires --box)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("EXAMPLES", char: "━", width: 50, color: {0, 180, 216})

    IO.puts(
      "# Basic table with headers and rows\n  alaja table --headers \"Name;Age;City\" --rows \"Alice;30;NYC|Bob;25;LA\"\n\n# Multiple --rows flags\n  alaja table --headers \"Name;Status\" --rows \"API;OK\" --rows \"DB;ERR\" --rows \"Cache;OK\"\n\n# Border styling with color and effects\n  alaja table --headers \"Service;Status\" --rows \"API;Running|DB;Stopped\" --border rounded --border-color cyan --border-effects bold\n\n# Header and row colors with alignment\n  alaja table --headers \"Name;Score\" --rows \"Alice;95|Bob;87\" --headers-color cyan --headers-align center,center --headers-effects bold --rows-color yellow --rows-align left,right\n\n# Per-column header colors\n  alaja table --headers \"Name;Age;City\" --rows \"Alice;30;NYC\" --headers-color \"red;green;blue\" --headers-align left,center,right\n\n# Table alignment\n  alaja table --headers \"A;B\" --rows \"1;2\" --table-align center --border double\n\n# All options combined\n  alaja table --headers \"Service;Status;Uptime\" --rows \"API;OK;99.9%|DB;WARN;95.2%|Cache;OK;100%\" --border rounded --border-color \"#00B4D8\" --border-effects bold --table-align center --headers-color cyan --headers-align left,center,right --headers-effects bold --rows-color \"green;yellow;green\" --rows-align left,center,right --rows-effects italic --padding 2\n\n# Raw positioning\n  alaja table --headers \"A;B\" --rows \"1;2\" --raw --pos-x 5 --pos-y 3\n\n# With box wrapper\n  alaja table --headers \"Name;Status\" --rows \"API;OK|DB;ERR\" --box --box-title \"Services\" --box-border double --box-color \"#FF6B6B\""
    )

    IO.puts("")
    :ok
  end
end
