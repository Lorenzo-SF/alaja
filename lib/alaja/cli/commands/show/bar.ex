defmodule Alaja.CLI.Commands.Show.Bar do
  @moduledoc "`alaja bar` — Display progress bars."

  alias Alaja.Buffer
  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.Bar, as: BarComp
  alias Alaja.Components.{Header, Separator, Table}
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
  def help do
    Header.print("Alaja Bar", subtitle: "Display progress bars", size: :small)
    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display a static progress bar with customizable fill characters,")
    IO.puts("  colors, label, width, and percentage display.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja bar <value> [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<value>", "Yes", "Current progress value (integer)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--max N", "integer", "1+", "100", "Maximum value for the progress bar"],
        ["--label TEXT", "string", "", "", "Label text displayed alongside the bar"],
        ["--width N", "integer", "1+", "40", "Width of the bar in characters"],
        [
          "--filled-char CHAR",
          "string",
          "Any character",
          "▓",
          "Character for the filled portion"
        ],
        ["--empty-char CHAR", "string", "Any character", "░", "Character for the empty portion"],
        ["--filled-color COLOR", "string", "Any color format", "", "Color of the filled portion"],
        ["--empty-color COLOR", "string", "Any color format", "", "Color of the empty portion"],
        ["--show-percent BOOL", "boolean", "", "true", "Show percentage value next to the bar"]
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
        ["alaja bar 75", "Basic progress bar (value 75 of 100)"],
        ["alaja bar 75 --max 100 --label \"CPU\"", "Custom max and label"],
        [
          "alaja bar 50 --width 60 --label \"Memory\" --show-percent false",
          "Custom width without percentage"
        ],
        [
          "alaja bar 80 --filled-char \"█\" --empty-char \"─\" --width 50",
          "Custom characters"
        ],
        [
          "alaja bar 75 --filled-color green --empty-color gray --label \"Disk\"",
          "Custom colors"
        ],
        [
          "alaja bar 65 --max 200 --label \"Upload\" --width 50 --filled-char \"▓\" --empty-char \"░\" --filled-color \"#00B4D8\" --empty-color \"#90E0EF\" --show-percent true",
          "All options combined"
        ],
        [
          "alaja bar 90 --label \"Download\" --filled-color cyan --raw --pos-x 5 --pos-y 3",
          "Raw positioning"
        ],
        [
          "alaja bar 45 --max 100 --label \"Progress\" --filled-color \"#FF6B6B\" --box --box-title \"Bar\" --box-border double --box-color \"#FFE66D\"",
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
