defmodule Alaja.CLI.Commands.Show.Ask do
  @moduledoc "`alaja ask` — Ask an interactive question."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Printer

  @help_data [
    title: "Alaja Ask",
    subtitle: "Ask an interactive text question",
    usage: "alaja ask <question> [--color C] [--align left|center|right]",
    description:
      "Reads a line of text from stdin and prints it to stdout. Suitable for shell scripts.",
    options: [
      {:color, :string, nil, "Prompt color"},
      {:align, :string, "left", "Alignment: left, center, right"}
    ],
    examples: [
      {"Simple prompt", "alaja ask \"What's your name?\""},
      {"Coloured prompt", "alaja ask \"Project name?\" --color cyan"},
      {"Centered", "alaja ask \"Continue?\" --align center"},
      {"Shell-scriptable", "name=$(alaja ask \"Username?\"); echo \"hi $name\""},
      {"With default in script", "read -p \"$(alaja ask 'Press enter to continue')\""}
    ]
  ]

  @doc "Runs the `alaja ask` command — interactively prompts a question read from stdin."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [color: :string, align: :string]
      )

    if global.help do
      help()
    else
      question = Enum.join(positional, " ")
      if question == "", do: help(global), else: ask(question, opts, global)
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
    case Alaja.CLI.Color.parse(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
