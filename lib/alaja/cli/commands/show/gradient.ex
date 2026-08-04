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
      {:from, :string, nil, "Start color (hex, rgb(), or named)"},
      {:to, :string, nil, "End color (hex, rgb(), or named)"},
      {:colors, :string, nil, "Comma-separated gradient stops"},
      {:direction, :string, "horizontal", "horizontal or vertical"},
      {:bg, :boolean, false, "Apply the gradient to the background instead of the foreground"},
      {:text_color, :string, nil, "Override the gradient with a single text color"}
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

    if global.help or Keyword.get(opts, :help, false) do
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
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp parse_direction(nil), do: :horizontal
  defp parse_direction("horizontal"), do: :horizontal
  defp parse_direction("vertical"), do: :vertical
  defp parse_direction(_), do: :horizontal

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help() :: :ok
  def help, do: HelpFormatter.render(@help_data)
end
