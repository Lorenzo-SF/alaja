defmodule Alaja.CLI.Commands.Show.Ask do
  @moduledoc "`alaja ask` — Ask an interactive question."

  @help_data [
    title: "Alaja Ask",
    subtitle: "Ask an interactive text question",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts

  alias Alaja.Printer

  @doc "Runs the `alaja ask` command — interactively prompts a question read from stdin."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [color: :string, align: :string]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      question = Enum.join(positional, " ")
      if question == "", do: help(), else: ask(question, opts, global)
    end
  end

  defp ask(question, opts, _global) do
    color = parse_color(Keyword.get(opts, :color))
    align = parse_align(Keyword.get(opts, :align))
    answer = Printer.Interactive.question(question, color: color, align: align)
    IO.write(answer)
  end

  defp parse_align(nil), do: :left
  defp parse_align(a) when is_atom(a), do: a

  defp parse_align(s) when is_binary(s) do
    case Alaja.Helpers.safe_string_to_atom(s) do
      {:ok, atom} -> atom
      {:error, _} -> :left
    end
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  @spec help() :: keyword()
  def help, do: @help_data
end
