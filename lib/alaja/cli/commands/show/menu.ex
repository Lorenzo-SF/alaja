defmodule Alaja.CLI.Commands.Show.Menu do
  @moduledoc "`alaja menu` — Display an interactive selection menu."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Header, Separator, Table}
  alias Alaja.Printer

  @doc "Runs the `alaja menu` command from raw argv — shows an interactive menu and prints the selected item."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [header: :string, color: :string, align: :string]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      header = Keyword.get(opts, :header) || Enum.at(items, 0)
      menu_items = if Keyword.get(opts, :header), do: items, else: Enum.drop(items, 1)
      color = parse_color(Keyword.get(opts, :color))
      align = parse_align(Keyword.get(opts, :align))

      if is_nil(header) or menu_items == [] do
        help()
      else
        options = Enum.map(menu_items, &{&1, &1})

        answer =
          Printer.Interactive.question_with_options("Selection", options,
            color: color,
            align: align
          )

        IO.write(to_string(answer))
      end
    end
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
  def help do
    Header.print("Alaja Menu",
      subtitle: "Display an interactive selection menu",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display an interactive menu where the user can select from")
    IO.puts("  multiple options using arrow keys. Returns the selected option.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja menu <header> <item1> [item2 ...] [options]")
    IO.puts("  alaja menu --header TEXT <item1> [item2 ...] [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<header>", "No", "Menu header/title (first positional arg if --header not used)"],
        ["<items>", "Yes", "Menu options (space-separated)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--header TEXT", "string", "", "", "Menu header text (overrides first positional arg)"],
        ["--color COLOR", "string", "Any color format", "", "Text color for menu items"],
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
        ["alaja menu \"Choose environment:\" \"prod\" \"staging\" \"dev\"", "Basic menu"],
        [
          "alaja menu --header \"Select:\" \"Option A\" \"Option B\" \"Option C\"",
          "Explicit header"
        ],
        [
          "alaja menu \"Pick a theme:\" \"Dark\" \"Light\" \"Auto\" --color cyan",
          "Colored menu"
        ],
        [
          "alaja menu --header \"Language:\" \"English\" \"Spanish\" \"French\" --align center --color yellow",
          "Centered alignment"
        ],
        [
          "alaja menu --header \"Server:\" \"US-East\" \"EU-West\" \"Asia-Pacific\" --color \"#00B4D8\" --box --box-title \"Menu\" --box-border double --box-color \"#FF6B6B\"",
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
