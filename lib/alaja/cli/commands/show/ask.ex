defmodule Alaja.CLI.Commands.Show.Ask do
  @moduledoc "`alaja ask` — Ask an interactive question."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Header, Separator, Table}
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

  @spec help() :: :ok
  def help do
    Header.print("Alaja Ask", subtitle: "Ask an interactive text question", size: :small)
    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Prompt the user with a text question and read their input.")
    IO.puts("  Returns the user's answer to stdout. Supports color and alignment.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja ask <question> [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<question>", "Yes", "Question text to display to the user"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--color COLOR", "string", "Any color format", "", "Color of the question text"],
        ["--align TYPE", "string", "left, center, right", "left", "Text alignment"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("GLOBAL OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--raw", "boolean", "", "false", "Print at raw coordinates"],
        ["--pos-x N", "integer", "0+", "0", "X coordinate (with --raw)"],
        ["--pos-y N", "integer", "0+", "0", "Y coordinate (with --raw)"],
        ["--verbose", "boolean", "", "false", "Return raw ANSI string instead of printing"],
        ["--box", "boolean", "", "false", "Wrap output in a bordered box"],
        ["--box-title TEXT", "string", "", "", "Box title (requires --box)"],
        [
          "--box-border TYPE",
          "string",
          "rounded, single, double, bold, none",
          "rounded",
          "Border style (requires --box)"
        ],
        ["--box-color COLOR", "string", "Any color format", "", "Border color (requires --box)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("EXAMPLES", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        ["alaja ask \"What is your name?\"", "Basic question"],
        ["alaja ask --color yellow \"Project name:\"", "Colored question"],
        [
          "alaja ask \"Enter your email:\" --color cyan --align center",
          "Centered alignment"
        ],
        [
          "alaja ask \"Password:\" --color red --align right",
          "Right-aligned with custom color"
        ],
        [
          "alaja ask \"API Key:\" --color \"#00B4D8\" --box --box-title \"Ask\" --box-border rounded --box-color \"#FF6B6B\"",
          "With box wrapper"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
  end
end
