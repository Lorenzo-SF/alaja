defmodule Alaja.CLI.Commands.Show.List do
  @moduledoc "`alaja list` — Display a styled list."

  @help_data [
    title: "Alaja List",
    subtitle: "Display a styled bullet list",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.List
  alias Alaja.Printer

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
  def help, do: @help_data
end
