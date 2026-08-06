defmodule Alaja.CLI.Commands.Show.Tabs do
  @moduledoc """
  `alaja tabs` — Stateful tabbed interface.

  Renders the tab strip produced by `Alaja.Components.TabsState`. The
  active tab is wrapped in `[ ... ]` and inverted. Use `--active N` to
  pick which tab is selected.
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.CLI.ViewText
  alias Alaja.Components
  alias Alaja.Printer

  @help_data [
    title: "Alaja Tabs",
    subtitle: "Stateful tabbed interface",
    usage: "alaja tabs <label1> <label2> ... <labelN> [--active N]",
    description: """
    Renders a labelled tab strip. The active tab is rendered with
    `[ ... ]` and an inverted style.
    """,
    options: [
      {:active, :integer, 0, "Zero-based index of the active tab"}
    ],
    examples: [
      {"Tabs con activo", "alaja tabs dev staging prod --active 1"},
      {"Tabs simple", "alaja tabs uno dos tres"}
    ]
  ]

  @doc "Runs the `alaja tabs` command."
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [
          active: :integer
        ]
      )

    if global.help or Keyword.get(opts, :help, false) or items == [] do
      help()
    else
      tabs_state = %Components.TabsState{
        labels: items,
        active: Keyword.get(opts, :active, 0)
      }

      Printer.print_raw(
        ViewText.render(Components.tabs_view(tabs_state)),
        GlobalOpts.to_printer_opts(global)
      )
    end
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
