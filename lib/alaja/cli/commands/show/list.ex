defmodule Alaja.CLI.Commands.Show.List do
  @moduledoc "`alaja list` — Display a styled list."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Header, Separator, Table}
  alias Alaja.Printer

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
      list_content = build_list_string(header, items, color, align)

      Printer.print_raw(list_content, GlobalOpts.to_printer_opts(global))
    end
  end

  defp build_list_string(nil, items, color, align) do
    items
    |> Enum.map_join("\n", &format_item(&1, color, align))
    |> then(&[&1, "\n"])
  end

  defp build_list_string(header, items, color, align) do
    header_line = "  #{header}"
    item_lines = Enum.map_join(items, "\n", &format_item(&1, color, align))
    [header_line, "\n", item_lines, "\n"]
  end

  defp format_item(item, nil, align) do
    apply_align("  • #{item}", align)
  end

  defp format_item(item, {r, g, b}, align) do
    apply_align(
      "#{Pote.Orchestrator.to_ansi({r, g, b})}  • #{item}#{Alaja.ANSI.reset_attributes()}",
      align
    )
  end

  # Alignment is relative to the terminal width for center/right.
  # Falls back gracefully when width cannot be determined.
  defp apply_align(line, :left), do: line

  defp apply_align(line, align) when align in [:center, :right] do
    # Strip ANSI to measure visible length
    visible_len = line |> String.replace(~r/\x1b\[[0-9;]*m/, "") |> String.length()
    term_width = term_width()

    padding =
      case align do
        :center -> max(0, div(term_width - visible_len, 2))
        :right -> max(0, term_width - visible_len)
      end

    String.duplicate(" ", padding) <> line
  end

  defp apply_align(line, _), do: line

  defp term_width do
    case :io.columns() do
      {:ok, w} -> w
      _ -> 80
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
  def help do
    Header.print("Alaja List", subtitle: "Display a styled bullet list", size: :small)
    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display a styled list with bullet points. Optionally include")
    IO.puts("  a header and customize colors and alignment.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja list <item1> [item2 ...] [options]")
    IO.puts("  alaja list --header TEXT <item1> [item2 ...] [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<items>", "Yes", "List items (space-separated)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--header TEXT", "string", "", "", "Optional list header/title"],
        ["--color COLOR", "string", "Any color format", "", "Bullet and text color"],
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
        ["alaja list \"Item 1\" \"Item 2\" \"Item 3\"", "Basic bullet list"],
        [
          "alaja list --header \"Options:\" \"Start\" \"Stop\" \"Restart\" --color cyan",
          "With header and color"
        ],
        [
          "alaja list \"Alpha\" \"Beta\" \"Gamma\" --align center --color yellow",
          "Centered alignment"
        ],
        [
          "alaja list \"Step 1\" \"Step 2\" \"Step 3\" --color green --raw --pos-x 5 --pos-y 2",
          "Raw positioning"
        ],
        [
          "alaja list --header \"Tasks:\" \"Build\" \"Test\" \"Deploy\" --color \"#00B4D8\" --box --box-title \"List\" --box-border rounded --box-color \"#FF6B6B\"",
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
