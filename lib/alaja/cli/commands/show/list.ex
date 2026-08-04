defmodule Alaja.CLI.Commands.Show.List do
  @moduledoc "`alaja list` — Display a styled list."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.List
  alias Alaja.Printer

  @help_data [
    title: "Alaja List",
    subtitle: "Display a styled bullet list",
    usage:
      "alaja list <item1> <item2> ... <itemN> [--header T] [--color C] [--align left|center|right]",
    description: "Renders a styled bullet list with optional header.",
    options: [
      {:header, :string, nil, "Optional header drawn above the list"},
      {:color, :string, nil, "Color of the list items"},
      {:align, :string, "left", "Alignment: left, center, right"}
    ]
  ]

  @doc "Runs the `alaja list` command from raw argv; prints help on `--help` or no items."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [header: :string, color: :string, align: :string]
      )

    if global.help or Keyword.get(opts, :help, false) or items == [] do
      help()
    else
      header = Keyword.get(opts, :header)
      color = parse_color(Keyword.get(opts, :color))
      align = parse_align(Keyword.get(opts, :align))
      list_content = List.build(items, header: header, color: color, align: align)

      Printer.print_raw(list_content, GlobalOpts.to_printer_opts(global))
    end
  end

  defp parse_align("center"), do: :center
  defp parse_align("right"), do: :right
  defp parse_align(_), do: :left

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  @spec help() :: :ok
  def help, do: HelpFormatter.render(@help_data)
end
