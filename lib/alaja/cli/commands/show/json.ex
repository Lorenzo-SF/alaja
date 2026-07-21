defmodule Alaja.CLI.Commands.Show.Json do
  @moduledoc "`alaja json` — Pretty-print JSON with syntax highlighting."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Header, Separator, Table}
  alias Alaja.Components.Json, as: JsonComp
  alias Alaja.Printer

  @doc "Runs the `alaja json` command from raw argv — pretty-prints a JSON string from argv or stdin."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          indent: :integer,
          key_color: :string,
          string_color: :string,
          number_color: :string,
          boolean_color: :string,
          null_color: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      json_str = Enum.join(positional, " ")

      if json_str == "" do
        IO.puts(:stderr, "Usage: alaja json '<json_string>'")
      else
        Code.ensure_compiled(Jason)
        decode_and_render(json_str, opts, global)
      end
    end
  end

  defp decode_and_render(json_str, opts, global) do
    case Jason.decode(json_str) do
      {:ok, data} -> render_json(data, opts, global)
      {:error, _} -> IO.puts(:stderr, "Invalid JSON: #{json_str}")
    end
  end

  defp render_json(data, opts, global) do
    json_opts =
      [
        indent: Keyword.get(opts, :indent),
        key_color: parse_color(Keyword.get(opts, :key_color)),
        string_color: parse_color(Keyword.get(opts, :string_color)),
        number_color: parse_color(Keyword.get(opts, :number_color)),
        boolean_color: parse_color(Keyword.get(opts, :boolean_color)),
        null_color: parse_color(Keyword.get(opts, :null_color))
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    rendered = JsonComp.render(data, json_opts)
    Printer.print_raw(rendered, printer_opts(global))
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help() :: :ok
  def help do
    Header.print("Alaja JSON",
      subtitle: "Pretty-print JSON with syntax highlighting",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Parse and pretty-print JSON data with syntax highlighting.")
    IO.puts("  Supports nested objects, arrays, strings, numbers, booleans,")
    IO.puts("  and null values with distinct colors for each type.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja json '<json_string>' [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<json_string>", "Yes", "JSON data as a string (wrap in quotes if it contains spaces)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--indent N", "integer", "1+", "2", "Indentation spaces"],
        ["--key-color COLOR", "string", "Any color format", "", "Color of object keys"],
        ["--string-color COLOR", "string", "Any color format", "", "Color of string values"],
        ["--number-color COLOR", "string", "Any color format", "", "Color of numbers"],
        ["--boolean-color COLOR", "string", "Any color format", "", "Color of booleans"],
        ["--null-color COLOR", "string", "Any color format", "", "Color of null values"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("GLOBAL OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
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

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        ["alaja json '{\"name\": \"Alice\", \"age\": 30}'", "Simple JSON object"],
        [
          "alaja json '{\"key\": \"value\", \"nested\": {\"foo\": \"bar\"}}'",
          "Nested JSON"
        ],
        ["alaja json '[\"apple\", \"banana\", \"cherry\"]'", "JSON array"],
        [
          "alaja json '{\"users\": [{\"name\": \"Alice\", \"roles\": [\"admin\", \"user\"]}, {\"name\": \"Bob\", \"roles\": [\"user\"]}]}'",
          "Complex nested structure"
        ],
        ["alaja json '{\"a\": 1}' --indent 4", "Custom indentation"],
        [
          "alaja json '{\"name\": \"test\", \"value\": 42, \"active\": true, \"data\": null}' --key-color red --string-color green --number-color yellow --boolean-color cyan --null-color gray",
          "Custom colors"
        ],
        ["alaja json '{\"status\": \"ok\"}' --raw --pos-x 5 --pos-y 3", "Raw positioning"],
        [
          "alaja json '{\"result\": 42, \"success\": true}' --box --box-title \"JSON\" --box-border double --box-color \"#00B4D8\"",
          "With box wrapper"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
  end
end
