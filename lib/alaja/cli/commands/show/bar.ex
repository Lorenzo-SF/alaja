defmodule Alaja.CLI.Commands.Show.Bar do
  @moduledoc "`alaja bar` — Display progress bars."

  @help_data [
    title: "Alaja Bar",
    subtitle: "Display progress bars",
    size: :small
  ]

  alias Alaja.Buffer
  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.Bar, as: BarComp

  alias Alaja.Printer

  @doc "Runs the `alaja bar` command from raw argv; prints help on `--help` or no value."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          max: :integer,
          label: :string,
          width: :integer,
          filled_char: :string,
          empty_char: :string,
          filled_color: :string,
          empty_color: :string,
          show_percent: :boolean
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      case positional do
        [value_str | _] -> render(value_str, opts, global)
        [] -> help()
      end
    end
  end

  defp render(value_str, opts, global) do
    value =
      case Integer.parse(value_str) do
        {n, ""} ->
          n

        _ ->
          IO.puts(:stderr, "Error: value must be an integer, got '#{value_str}'")
          exit({:shutdown, 1})
      end

    max = Keyword.get(opts, :max, 100)
    label = Keyword.get(opts, :label)
    width = Keyword.get(opts, :width, 40)

    bar_opts =
      [
        label: label,
        width: width,
        filled_char: Keyword.get(opts, :filled_char),
        empty_char: Keyword.get(opts, :empty_char),
        filled_color: parse_color(Keyword.get(opts, :filled_color)),
        empty_color: parse_color(Keyword.get(opts, :empty_color)),
        show_percent: Keyword.get(opts, :show_percent, true)
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    rendered = BarComp.render(value, max, bar_opts)
    rendered_iodata = Buffer.to_iodata(rendered)
    output = if global.raw, do: rendered_iodata, else: ["  ", rendered_iodata]
    Printer.print_raw(output, printer_opts(global))
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
  def help, do: @help_data
end
