defmodule Alaja.CLI.Commands.Show.Separator do
  @moduledoc "`alaja separator` — Display horizontal separator lines."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Separator, as: SepComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Separator",
    subtitle: "Display horizontal separator lines",
    usage: "alaja separator [--char C] [--width N] [--text T] [--color C]",
    description: "Draws a horizontal rule of the given character, optionally with embedded text.",
    options: [
      {:char, :string, "─", "Character used to draw the line"},
      {:width, :integer, 60, "Total width in characters"},
      {:text, :string, nil, "Optional text embedded in the line"},
      {:color, :string, nil, "Color of the line"}
    ],
    examples: [
      {"Separador con título", "alaja separator \"DEPLOY\" --width 60 --color cyan"},
      {"Línea simple con carácter propio", "alaja separator --char \"*\" --width 40"}
    ]
  ]

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

  @doc "Prints help for the separator command."
  @spec help() :: :ok
  def help, do: HelpFormatter.render(@help_data)
end
