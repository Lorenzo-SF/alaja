defmodule Alaja.CLI.Commands.Show.Progress do
  @moduledoc """
  `alaja progress` — Stateful progress bar.

  Renders a progress bar from `Alaja.Components.ProgressState`. Differs
  from `alaja bar` in that the state lives in a struct (`:current`,
  `:total`, `:width`, `:label`) and the bar is laid out by the
  component, not by the CLI.
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.CLI.ViewText
  alias Alaja.Components
  alias Alaja.Printer

  @help_data [
    title: "Alaja Progress",
    subtitle: "Stateful progress bar",
    usage: "alaja progress [--current N] [--total N] [--width N] [--label T]",
    description: """
    Renders a progress bar from `Alaja.Components.ProgressState`. The
    `:current` value is clamped to `[0, :total]`. Defaults to 0/100
    width 20, no label.
    """,
    options: [
      {:current, :integer, 0, "Current value"},
      {:total, :integer, 100, "Maximum value"},
      {:width, :integer, 20, "Bar width in characters"},
      {:label, :string, "", "Optional label drawn to the left of the bar"}
    ],
    examples: [
      {"Default state", "alaja progress"},
      {"Half-way", "alaja progress --current 50"},
      {"With label", "alaja progress --current 75 --total 100 --label \"deploy\""},
      {"Wider bar", "alaja progress --current 30 --width 40 --label \"download\""},
      {"From script", "for pct in 0 25 50 75 100; do alaja progress --current $pct --label \"step $pct\"; done"}
    ]
  ]

  @doc "Runs the `alaja progress` command."
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          current: :integer,
          total: :integer,
          width: :integer,
          label: :string
        ]
      )

    if global.help do
      help()
    else
      progress_state = %Components.ProgressState{
        current: Keyword.get(opts, :current, 0),
        total: Keyword.get(opts, :total, 100),
        width: Keyword.get(opts, :width, 20),
        label: Keyword.get(opts, :label, "")
      }

      Printer.print_raw(
        ViewText.render(Components.progress_view(progress_state)),
        GlobalOpts.to_printer_opts(global)
      )
    end
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
