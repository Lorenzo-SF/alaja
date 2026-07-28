defmodule Alaja.CLI.Commands.Show.YesNo do
  @moduledoc "`alaja yesno` — Ask a Yes/No question."

  @help_data [
    title: "Alaja YesNo",
    subtitle: "Ask an interactive Yes/No question",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts

  alias Alaja.Printer

  @doc "Runs the `alaja yesno` command — interactively reads a y/n answer from stdin and prints it."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [default: :string, color: :string, align: :string]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      question = Enum.join(positional, " ")
      if question == "", do: help(), else: ask(question, opts, global)
    end
  end

  defp ask(question, opts, _global) do
    default =
      case Keyword.get(opts, :default, "no") do
        "yes" -> :yes
        "y" -> :yes
        _ -> :no
      end

    color = parse_color(Keyword.get(opts, :color))
    align = parse_align(Keyword.get(opts, :align))

    result = Printer.Interactive.yesno(question, default: default, color: color, align: align)
    IO.write(if result == :yes, do: "yes", else: "no")
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp parse_align(nil), do: :left
  defp parse_align(a) when is_atom(a), do: a

  defp parse_align(s) when is_binary(s) do
    case Alaja.Helpers.safe_string_to_atom(s) do
      {:ok, atom} -> atom
      {:error, _} -> :left
    end
  end

  @spec help() :: :ok
  def help, do: @help_data
end
