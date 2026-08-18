defmodule Alaja.CLI.Commands.Show.Gradient do
  @moduledoc "`alaja gradient` — Display gradient-colored text."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Gradient, as: GradComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Gradient",
    subtitle: "Gradient-colored text (multi-color support)",
    usage:
      "alaja gradient <text> [--from C] [--to C] [--colors C,C,C] [--direction horizontal|vertical] [--bg] [--text-color C]",
    description: """
    Renders text with a gradient color treatment. Specify either
    `--from` and `--to` (linear interpolation) or a `--colors` list
    specifying the gradient stops.
    """,
    options: [
      {:from, :string, nil, "Start color (<formato>:<codigo> o #hex)"},
      {:to, :string, nil, "End color (<formato>:<codigo> o #hex)"},
      {:colors, :string, nil, "Pipe-separated gradient stops (hex:a|hex:b|hex:c)"},
      {:direction, :string, "horizontal", "horizontal or vertical"},
      {:bg, :boolean, false, "Apply the gradient to the background instead of the foreground"},
      {:text_color, :string, nil, "Override the gradient with a single text color"}
    ],
    examples: [
      {"Two-stop horizontal", "alaja gradient \"alaja\" --from hex:ff6b6b --to hex:4ecdc4"},
      {"Three-stop rainbow", "alaja gradient \"ship it\" --colors hex:ff0000|hex:00ff00|hex:0000ff"},
      {"Vertical gradient", "alaja gradient \"release\" --from #FFFF00 --to hex:ff00ff --direction vertical"},
      {"Background gradient", "alaja gradient \"urgent\" --from red --to yellow --bg"},
      {"Single-colour override", "alaja gradient \"quiet\" --text-color grey"},
      {"Brand title", "alaja gradient \"CACAFUTI\" --colors hex:7aa2f7|hex:f5c2e7|hex:abe9b3"}
    ]
  ]

  @doc "Runs the gradient command."
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          from: :string,
          to: :string,
          colors: :string,
          direction: :string,
          bg: :boolean,
          text_color: :string
        ]
      )

    if global.help do
      help()
    else
      text = Enum.join(positional, " ")
      render(text, opts, global)
    end
  end

  defp render(text, opts, global) do
    grad_opts =
      [
        from: parse_color(Keyword.get(opts, :from)),
        to: parse_color(Keyword.get(opts, :to)),
        # Pass the raw string to the back-end; the component parses it.
        colors: Keyword.get(opts, :colors),
        direction: parse_direction(Keyword.get(opts, :direction)),
        bg: Keyword.get(opts, :bg, false),
        text_color: parse_color(Keyword.get(opts, :text_color))
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    rendered = GradComp.render(text, grad_opts)
    Printer.print_raw(rendered, printer_opts(global))
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Alaja.CLI.Color.parse(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp parse_direction(nil), do: :horizontal
  defp parse_direction("horizontal"), do: :horizontal
  defp parse_direction("vertical"), do: :vertical
  defp parse_direction(_), do: :horizontal

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
