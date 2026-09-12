defmodule Alaja.CLI.Commands.Show.YesNo do
  @moduledoc "`alaja yesno` — Ask a Yes/No question."

  alias Alaja.CLI.Color
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Printer

  @help_data [
    title: "Alaja YesNo",
    subtitle: "Ask an interactive Yes/No question",
    usage: "alaja yesno <question> [--default yes|no] [--color C] [--align left|center|right]",
    description:
      "Reads a yes/no answer from stdin and prints `yes` or `no` to stdout. Suitable for shell scripts.",
    options: [
      {:default, :string, "no", "Default answer if input is empty (yes/no, y/n)"},
      {:color, :string, nil, "Prompt color"},
      {:align, :string, "left", "Alignment: left, center, right"}
    ],
    examples: [
      {"Default no", "alaja yesno \"Continue?\""},
      {"Default yes", "alaja yesno \"Apply migrations?\" --default yes"},
      {"Destructive (red)", "alaja yesno \"Drop database?\" --color red"},
      {"In a shell script", "if [ \"$(alaja yesno 'Deploy to prod?')\" = yes ]; then deploy; fi"},
      {"Wrap with box", "alaja yesno \"Ship it?\" --box --box-title CONFIRM"}
    ]
  ]

  @doc "Runs the `alaja yesno` command — interactively reads a y/n answer from stdin and prints it."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [default: :string, color: :string, align: :string]
      )

    if global.help do
      help()
    else
      question = Enum.join(positional, " ")
      if question == "", do: help(global), else: ask(question, opts, global)
    end
  end

  defp ask(question, opts, _global) do
    default =
      case Keyword.get(opts, :default, "no") do
        "yes" -> :yes
        "y" -> :yes
        _ -> :no
      end

    color = Color.parse_or_nil(Keyword.get(opts, :color))
    align = parse_align(Keyword.get(opts, :align))

    result = Printer.Interactive.yesno(question, default: default, color: color, align: align)
    IO.write(if result == :yes, do: "yes", else: "no")
  end

  # parse_color/1 delegates to Alaja.CLI.Color.parse_or_nil/1

  defp parse_align(nil), do: :left
  defp parse_align(a) when is_atom(a), do: a

  defp parse_align(s) when is_binary(s) do
    case Alaja.Helpers.safe_string_to_atom(s) do
      {:ok, atom} -> atom
      {:error, _} -> :left
    end
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
