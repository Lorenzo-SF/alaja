defmodule Alaja.CLI.Commands.Show.Animate do
  @moduledoc "`alaja animate` — Display animated spinners and indicators."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Animate

  @help_data [
    title: "Alaja Animate",
    subtitle: "Display animated spinners and indicators",
    usage:
      "alaja animate [--type spinner|kitt|pulse|wave|rainbow] [--duration N] [--text T] [--color C] [--speed N] [--chars C] [--colors C,C,C]",
    description: """
    Renders a spinner-style animation. Use `--duration` (in seconds) to
    bound the animation; omit for an indefinite loop. The kitt animation
    uses a trailing-character sweep.
    """,
    options: [
      {:type, :string, "spinner", "Animation type: spinner, kitt, pulse, wave, rainbow"},
      {:duration, :integer, 3, "Total duration in seconds"},
      {:text, :string, "Loading", "Text drawn before the spinner"},
      {:color, :string, nil, "Single color for the animation"},
      {:speed, :integer, 100, "Frames per second"},
      {:chars, :string, nil, "Custom spinner characters (overrides the type defaults)"},
      {:colors, :string, nil, "Comma-separated list of colors for multi-color animations"}
    ],
    examples: [
      {"Spinner con texto", "alaja animate --type dots --text \"working\" --duration 2000"},
      {"Spinner de línea", "alaja animate --type line --text \"loading\" --color cyan --duration 1500"}
    ]
  ]

  @doc "Runs the `alaja animate` command from raw argv; prints help on `--help`."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          type: :string,
          duration: :integer,
          text: :string,
          color: :string,
          speed: :integer,
          chars: :string,
          colors: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      type = Keyword.get(opts, :type, "spinner")
      duration = Keyword.get(opts, :duration, 3)
      text = Keyword.get(opts, :text, "Loading")
      speed = Keyword.get(opts, :speed, 100)
      verbose = global.verbose

      frames = Animate.frames(type, Keyword.get(opts, :chars))
      colors = Animate.parse_colors(Keyword.get(opts, :color), Keyword.get(opts, :colors))

      {cr, cg, cb} =
        case colors do
          [first | _] -> first
          [] -> {0, 180, 216}
        end

      if type == "kitt" do
        Animate.run_kitt(text, duration, speed, {cr, cg, cb}, verbose, frames, colors)
      else
        Animate.run_animation(frames, duration, speed, text, {cr, cg, cb}, verbose, colors)
      end
    end
  end

  @spec help() :: :ok
  def help, do: HelpFormatter.render(@help_data)
end
