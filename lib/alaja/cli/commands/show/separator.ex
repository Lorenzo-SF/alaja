defmodule Alaja.CLI.Commands.Show.Separator do
  @moduledoc "`alaja separator` — Display horizontal separator lines."

  alias Alaja.CLI.Color
  alias Alaja.CLI.Commands.Base
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Separator, as: SepComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Separator",
    subtitle: "Display horizontal separator lines",
    usage:
      "alaja separator [--char C] [--text T] [--separator-color C] [--text-color C] [--width N]",
    description: """
    Draws a horizontal rule of the given character, optionally with an
    embedded label.

    `--separator-color` (or the legacy alias `--color`) drives the colour
    of the decorative characters; `--text-color` (defaults to the
    separator colour) drives the colour of the centred label.
    """,
    options: [
      {:char, :string, "─", "Character used to draw the decorative line"},
      {:width, :integer, nil,
       "Total width in characters (defaults to terminal width)"},
      {:text, :string, nil, "Optional label embedded in the line"},
      {:separator_color, :string, nil, "Colour for the decorative characters"},
      {:color, :string, nil, "Alias for --separator-color (kept for back-compat)"},
      {:text_color, :string, nil, "Colour of the centred label (defaults to separator colour)"}
    ],
    examples: [
      {"Plain rule", "alaja separator"},
      {"Embedded title",
       "alaja separator \"DEPLOY\" --separator-color hex:#00ffff --text-color hex:#ff00ff"},
      {"Custom character",
       "alaja separator --char \"=\" --width 40 --separator-color theme:secondary"},
      {"Thin line with title",
       "alaja separator \"Section\" --char \"─\" --separator-color grey"}
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
        switches: [
          char: :string,
          width: :integer,
          text: :string,
          separator_color: :string,
          color: :string,
          text_color: :string
        ]
      )

    if global.help do
      help()
    else
      render(opts, global)
    end
  end

  defp render(opts, global) do
    char = Keyword.get(opts, :char, "─")
    width = Keyword.get(opts, :width) || Base.term_width()
    text = Keyword.get(opts, :text)
    separator_color =
      Color.parse_or_nil(Keyword.get(opts, :separator_color) || Keyword.get(opts, :color))
    text_color = Color.parse_or_nil(Keyword.get(opts, :text_color))

    rendered =
      SepComp.render(text,
        char: char,
        width: width,
        separator_color: separator_color,
        text_color: text_color
      )

    Printer.print_raw(rendered, printer_opts(global))
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc "Prints help for the separator command."
  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
