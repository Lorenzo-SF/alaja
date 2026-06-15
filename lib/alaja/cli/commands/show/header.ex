defmodule Alaja.CLI.Commands.Show.Header do
  @moduledoc "`alaja header` — Display styled headers."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.Header, as: HeaderComp
  alias Alaja.Components.{Separator, Table}
  alias Alaja.Printer

  @doc """
  Runs the header command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          subtitle: :string,
          size: :string,
          color: :string,
          subtitle_color: :string,
          width: :integer
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      title = Enum.join(positional, " ")
      if title == "", do: help(), else: render(title, opts, global)
    end
  end

  defp render(title, opts, global) do
    rendered =
      HeaderComp.render(title,
        subtitle: Keyword.get(opts, :subtitle),
        size:
          case Alaja.Helpers.safe_string_to_atom(Keyword.get(opts, :size, "medium")) do
            {:ok, atom} -> atom
            {:error, _} -> :medium
          end,
        color: parse_color(Keyword.get(opts, :color)),
        subtitle_color: parse_color(Keyword.get(opts, :subtitle_color)),
        width: Keyword.get(opts, :width, 80)
      )

    Printer.print_raw(rendered, printer_opts(global))
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc """
  Prints help for the header command.
  """
  @spec help() :: :ok
  def help do
    HeaderComp.print("Alaja Header",
      subtitle: "Display styled headers with optional subtitle",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display a styled header with decorative lines above and below the title.")
    IO.puts("  Supports optional subtitle, custom sizes, colors, and width.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja header <title> [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<title>", "Yes", "Header text to display"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--subtitle TEXT", "string", "", "", "Subtitle text displayed below the title"],
        [
          "--size TYPE",
          "string",
          "small, medium, large",
          "medium",
          "Header size (affects line length and font)"
        ],
        ["--color COLOR", "string", "Any color format", "", "Title text color"],
        ["--subtitle-color COLOR", "string", "Any color format", "", "Subtitle text color"],
        ["--width N", "integer", "1+", "80", "Total width of the header in characters"]
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
        ["alaja header \"Dashboard\"", "Basic header"],
        [
          "alaja header \"System Status\" --subtitle \"v2.0 — Production\" --size large",
          "With subtitle and size"
        ],
        [
          "alaja header \"Alert\" --subtitle \"Critical issue detected\" --color red --subtitle-color yellow --width 60",
          "Custom colors"
        ],
        [
          "alaja header \"Panel\" --subtitle \"Data view\" --raw --pos-x 5 --pos-y 2",
          "Raw positioning"
        ],
        [
          "alaja header \"Report\" --subtitle \"Monthly summary\" --color cyan --box --box-title \"Header\" --box-border double --box-color \"#00B4D8\"",
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
