defmodule Alaja.CLI.Commands.Show.Scroll do
  @moduledoc """
  `alaja scroll` — Stateful scrollable list.

  Renders a list with an interactive-feeling output: a `>` marker on the
  selected item, inline rendering of the visible window, and args
  `--select N`, `--max-visible N` to control the slice.

  Backed by `Alaja.Components.ListState`. Use ↑/↓ in interactive apps;
  here it's a snapshot.
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.CLI.ViewText
  alias Alaja.Components
  alias Alaja.Printer

  @help_data [
    title: "Alaja Scroll",
    subtitle: "Stateful scrollable list",
    usage: "alaja scroll <item1> <item2> ... <itemN> [--select N] [--max-visible N] [--offset N]",
    description: """
    Renders a stateful list built by `Alaja.Components.ListState`. The
    `--select` flag picks which item is highlighted with a `>` marker;
    `--max-visible` controls the window size; `--offset` is the top
    index of the window.
    """,
    options: [
      {:select, :integer, 0, "Zero-based index of the selected item"},
      {:max_visible, :integer, 10, "Window size"},
      {:offset, :integer, 0, "Top index of the window (used with --max-visible)"}
    ],
    examples: [
      {"Lista con selección", "alaja scroll a b c --select 1"},
      {"Ventana con scroll", "alaja scroll one two three four --max-visible 2 --offset 2"}
    ]
  ]

  @doc "Runs the `alaja scroll` command."
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [
          select: :integer,
          max_visible: :integer,
          offset: :integer
        ]
      )

    if global.help or Keyword.get(opts, :help, false) or items == [] do
      help()
    else
      list_state =
        %Components.ListState{
          items: items,
          selected: Keyword.get(opts, :select, 0),
          offset: Keyword.get(opts, :offset, 0),
          max_visible: Keyword.get(opts, :max_visible, 10)
        }

      Printer.print_raw(
        ViewText.render(Components.list_view(list_state)),
        GlobalOpts.to_printer_opts(global)
      )
    end
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
