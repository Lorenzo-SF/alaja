defmodule Alaja.CLI.Commands.Show.Log do
  @moduledoc """
  `alaja log` — Append-only log.

  Renders a list of lines as a log using `Alaja.Components.LogState`.
  Each positional argument is a log line. `--max-lines N` caps the
  number of retained lines (oldest dropped).
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.CLI.ViewText
  alias Alaja.Components
  alias Alaja.Printer

  @help_data [
    title: "Alaja Log",
    subtitle: "Append-only log",
    usage: "alaja log <line1> <line2> ... <lineN> [--max-lines N]",
    description: """
    Renders each positional argument as a log line. Lines are appended
    in order; `--max-lines` keeps the most recent N (oldest dropped).
    """,
    options: [
      {:max_lines, :integer, 1000, "Maximum number of lines to retain"}
    ],
    examples: [
      {"Log con retención", "alaja log \"line 1\" \"line 2\" --max-lines 5"},
      {"Log simple", "alaja log \"iniciando\" \"deploy ok\""}
    ]
  ]

  @doc "Runs the `alaja log` command."
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [
          max_lines: :integer
        ]
      )

    if global.help or Keyword.get(opts, :help, false) or items == [] do
      help()
    else
      log_state =
        Enum.reduce(
          items,
          %Components.LogState{max_lines: Keyword.get(opts, :max_lines, 1000)},
          fn
            line, acc -> Components.log_append(acc, line)
          end
        )

      Printer.print_raw(
        ViewText.render(Components.log_view(log_state)),
        GlobalOpts.to_printer_opts(global)
      )
    end
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
