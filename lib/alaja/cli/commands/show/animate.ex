defmodule Alaja.CLI.Commands.Show.Animate do
  @moduledoc "`alaja animate` — Display animated spinners and indicators."

  @help_data [
    title: "Alaja Animate",
    subtitle: "Display animated spinners and indicators",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.Animate

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
  def help, do: @help_data
end
