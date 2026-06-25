defmodule Alaja.CLI.Commands.Show.Breadcrumbs do
  @moduledoc "`alaja breadcrumbs` — Display navigation breadcrumbs."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.Breadcrumbs, as: BCComp
  alias Alaja.Components.{Header, Separator, Table}
  alias Alaja.Printer
  alias Alaja.Buffer
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [
          separator: :string,
          color: :string,
          separator_color: :string,
          current_color: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) or items == [] do
      help()
    else
      bc_opts =
        [
          separator: Keyword.get(opts, :separator),
          item_color: parse_color(Keyword.get(opts, :color)),
          separator_color: parse_color(Keyword.get(opts, :separator_color)),
          current_color: parse_color(Keyword.get(opts, :current_color))
        ]
        |> Enum.reject(fn {_, v} -> is_nil(v) end)

      rendered = BCComp.render(items, bc_opts)
      rendered_iodata = if is_list(rendered), do: rendered, else: Buffer.to_iodata(rendered)

      output = if global.raw, do: rendered_iodata, else: ["  ", rendered_iodata]
      Printer.print_raw(output, printer_opts(global))
    end
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help() :: :ok
  def help do
    Header.print("Alaja Breadcrumbs",
      subtitle: "Display navigation breadcrumbs",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display a navigation breadcrumb trail with customizable")
    IO.puts("  separators, colors, and styling.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja breadcrumbs <item1> [item2 ...] [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<items>", "Yes", "Navigation path items (space-separated, e.g.: Home Projects App)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        [
          "--separator TEXT",
          "string",
          "Any text",
          "›",
          "Separator text between breadcrumb items"
        ],
        [
          "--color COLOR",
          "string",
          "Any color format",
          "cyan",
          "Color of the breadcrumb item text"
        ],
        [
          "--current-color COLOR",
          "string",
          "Any color format",
          "white",
          "Color of the last (current) breadcrumb item"
        ],
        [
          "--separator-color COLOR",
          "string",
          "Any color format",
          "gray",
          "Color of the separator characters"
        ]
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
        ["alaja breadcrumbs Home Projects Alaja", "Basic breadcrumbs"],
        ["alaja breadcrumbs / home users admin --separator \"/\"", "Custom separator"],
        [
          "alaja breadcrumbs Home Dashboard Settings --color cyan --current-color white --separator-color gray",
          "Custom colors"
        ],
        [
          "alaja breadcrumbs Home App --color green --current-color yellow --separator \"→\" --separator-color yellow --raw --pos-x 5 --pos-y 3",
          "Raw positioning"
        ],
        [
          "alaja breadcrumbs Home Projects Alaja --color \"#00B4D8\" --current-color \"#FFFFFF\" --separator \"›\" --separator-color \"#90E0EF\" --box --box-title \"Navigation\" --box-border rounded",
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
