defmodule Alaja.CLI.Commands.Show.Json do
  @moduledoc "`alaja json` — Pretty-print JSON with syntax highlighting."

  @help_data [
    title: "Alaja JSON",
    subtitle: "Pretty-print JSON with syntax highlighting",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts

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

  @spec help() :: keyword()
  def help, do: @help_data
end
