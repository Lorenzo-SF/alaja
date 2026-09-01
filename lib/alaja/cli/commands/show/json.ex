defmodule Alaja.CLI.Commands.Show.Json do
  @moduledoc "`alaja json` — Pretty-print JSON with syntax highlighting."

  alias Alaja.CLI.Color
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Json, as: JsonComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja JSON",
    subtitle: "Pretty-print JSON with syntax highlighting",
    usage:
      "alaja json '<json_string>' [--indent N] [--key-color C] [--string-color C] [--number-color C] [--boolean-color C] [--null-color C] [--punctuation-color C]",
    description:
      "Pretty-prints JSON with per-token color highlighting. The JSON is read from argv (concatenated positional args).",
    options: [
      {:indent, :integer, nil, "Indent width in spaces (default depends on back)"},
      {:key_color, :string, nil, "Color for keys"},
      {:string_color, :string, nil, "Color for string values"},
      {:number_color, :string, nil, "Color for numeric values"},
      {:boolean_color, :string, nil, "Color for booleans"},
      {:null_color, :string, nil, "Color for null"},
      {:punctuation_color, :string, nil, "Color for punctuation (brackets, commas, colons)"}
    ],
    examples: [
      {"Inline JSON", "alaja json '{\"name\":\"alaja\",\"v\":3}'"},
      {"From stdin", "echo '{\"ok\":true,\"n\":1}' | alaja json"},
      {"Custom indent", "alaja json '{\"a\":1}' --indent 4"},
      {"Pipe a real file", "cat config.json | alaja json"},
      {"API response in CI", "curl -s https://api.example.com/v1/health | alaja json"},
      {"Monochrome (no colour)", "alaja json '{\"k\":\"v\"}' --no-color"}
    ]
  ]

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
          null_color: :string,
          punctuation_color: :string
        ]
      )

    if global.help do
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
        key_color: Color.parse_or_nil(Keyword.get(opts, :key_color)),
        string_color: Color.parse_or_nil(Keyword.get(opts, :string_color)),
        number_color: Color.parse_or_nil(Keyword.get(opts, :number_color)),
        boolean_color: Color.parse_or_nil(Keyword.get(opts, :boolean_color)),
        null_color: Color.parse_or_nil(Keyword.get(opts, :null_color)),
        punctuation_color: Color.parse_or_nil(Keyword.get(opts, :punctuation_color))
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    rendered = JsonComp.render(data, json_opts)
    Printer.print_raw(rendered, printer_opts(global))
  end

  # parse_color/1 delegates to Alaja.CLI.Color.parse_or_nil/1

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
