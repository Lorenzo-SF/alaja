defmodule Alaja.CLI.Commands.Show.Separator do
  @moduledoc "`alaja separator` — Display horizontal separator lines."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Header, Table}
  alias Alaja.Components.Separator, as: SepComp

  alias Alaja.Printer

  @doc """
  Runs the separator command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [char: :string, width: :integer, text: :string, color: :string]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      render(opts, global)
    end
  end

  defp render(opts, global) do
    char = Keyword.get(opts, :char, "─")
    width = Keyword.get(opts, :width, 60)
    text = Keyword.get(opts, :text)
    color = parse_color(Keyword.get(opts, :color))

    rendered = SepComp.render(text, char: char, width: width, color: color)
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

  @doc """
  Prints help for the separator command.
  """
  @spec help() :: :ok
  def help do
    Header.print("Alaja Separator",
      subtitle: "Display horizontal separator lines",
      size: :small
    )

    IO.puts("")

    SepComp.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display a horizontal separator line. Supports custom characters,")
    IO.puts("  width, optional centered text, and color.")
    IO.puts("")

    SepComp.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja separator [options]")
    IO.puts("")

    SepComp.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        [
          "--char TEXT",
          "string",
          "Any character(s)",
          "─",
          "Character used for the separator line"
        ],
        ["--width N", "integer", "1+", "60", "Width of the separator line in characters"],
        ["--text TEXT", "string", "", "", "Optional text centered in the separator"],
        ["--color COLOR", "string", "Any color format", "", "Color of the separator line"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    SepComp.print("GLOBAL OPTIONS", char: "━", width: 50, color: {0, 180, 216})

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

    SepComp.print("EXAMPLES", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        ["alaja separator", "Basic separator (default: ─, width 60)"],
        ["alaja separator --char \"═\" --width 80", "Custom character and width"],
        [
          "alaja separator --text \"Section Title\" --char \"━\" --width 50",
          "With centered text"
        ],
        ["alaja separator --char \"─\" --width 80 --color cyan", "Colored separator"],
        [
          "alaja separator --text \"Important\" --char \"★\" --width 40 --color yellow --raw --pos-x 10 --pos-y 5",
          "All options combined"
        ],
        [
          "alaja separator --text \"Divider\" --color \"#00B4D8\" --box --box-title \"Separator\" --box-border rounded",
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
