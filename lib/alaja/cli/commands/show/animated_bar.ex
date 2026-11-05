defmodule Alaja.CLI.Commands.Show.AnimatedBar do
  @moduledoc "`alaja animated-bar` — Animated progress bar."

  alias Alaja.CLI.HelpFormatter

  @help_data [
    title: "Alaja Animated Bar",
    subtitle: "Animated progress bar",
    usage:
      "alaja animated-bar <value> [--max N] [--type spinner|kitt|pulse|wave|rainbow] [--label T] [--width N] [--filled-char C] [--empty-char C] [--filled-color C] [--empty-color C] [--animation-color C] [--speed N] [--duration N] [--max-iterations N] [--show-percent] [--kitt-width N] [--verbose]",
    description: """
    Renders an animated horizontal progress bar. Animates `value` (or any
    value passed positionally) using the chosen animation type. `--duration`
    in milliseconds terminates the animation; `--max-iterations` caps the frame
    loop independently of duration.

    `--animation-color` overrides `--filled-color` for the moving
    animation cells in all types except `:rainbow` (where the colour
    is the whole point).
    """,
    options: [
      {:value, :integer, nil, "Numeric value (or pass as positional arg)"},
      {:max, :integer, 100, "Maximum value"},
      {:type, :string, "spinner", "Animation type: spinner, kitt, pulse, wave, rainbow"},
      {:label, :string, nil, "Optional label"},
      {:width, :integer, 40, "Bar width in characters"},
      {:filled_char, :string, "▓", "Filled portion character"},
      {:empty_char, :string, "░", "Empty portion character"},
      {:filled_color, :string, "success", "Filled portion color"},
      {:empty_color, :string, "background", "Empty portion color"},
      {:animation_color, :string, nil,
       "Color of the moving animation cells (all types except rainbow)"},
      {:speed, :integer, 100, "Frames per second"},
      {:duration, :integer, nil, "Stop after N milliseconds (omit for unlimited)"},
      {:max_iterations, :integer, nil, "Hard cap on frame count"},
      {:show_percent, :boolean, true, "Show percent label"},
      {:kitt_width, :integer, 3, "Width of the kitt animation tail"},
      {:verbose, :boolean, false, "Dump 20 frames to stdout instead of animating"}
    ],
    examples: [
      {"Quick demo (2s)", "alaja animated-bar 50 --max 100 --duration 2000"},
      {"Spinner style", "alaja animated-bar 30 --type spinner --duration 3000"},
      {"KITT-style sweep", "alaja animated-bar 70 --type kitt --kitt-width 5 --duration 4000"},
      {"Pulse with custom animation colour",
       "alaja animated-bar 0 --max 100 --type pulse --animation-color yellow --duration 2000 --label \"thinking...\""},
      {"Wave", "alaja animated-bar 80 --type wave --filled-color cyan --duration 2500"},
      {"Rainbow", "alaja animated-bar 50 --type rainbow --duration 3000"},
      {"Snapshot frames to stdout", "alaja animated-bar 50 --max 100 --verbose"}
    ]
  ]

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.AnimatedBar, as: ABComp

  @doc "Runs the `alaja animated-bar` command from raw argv; prints help on `--help` or no value."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          value: :integer,
          max: :integer,
          label: :string,
          type: :string,
          width: :integer,
          filled_char: :string,
          empty_char: :string,
          filled_color: :string,
          empty_color: :string,
          animation_color: :string,
          speed: :integer,
          duration: :integer,
          show_percent: :boolean,
          kitt_width: :integer,
          max_iterations: :integer,
          verbose: :boolean
        ]
      )

    if global.help do
      help(global)
    else
      value = parse_value(opts, positional)
      if is_nil(value), do: help(global), else: render(value, opts, global)
    end
  end

  defp parse_value(opts, positional) do
    val = Keyword.get(opts, :value)
    if val, do: val, else: parse_first(positional)
  end

  defp parse_first([h | _]), do: parse_int(h)
  defp parse_first([]), do: nil

  defp parse_int(s) do
    case Integer.parse(s) do
      {n, _} -> n
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  defp render(value, opts, global) do
    max = Keyword.get(opts, :max, 100)
    speed = Keyword.get(opts, :speed, 100)
    duration = Keyword.get(opts, :duration)
    max_iterations = Keyword.get(opts, :max_iterations)

    bar_opts =
      [
        animation: parse_type(Keyword.get(opts, :type, "spinner")),
        width: Keyword.get(opts, :width, 40),
        label: Keyword.get(opts, :label),
        filled_char: Keyword.get(opts, :filled_char),
        empty_char: Keyword.get(opts, :empty_char),
        filled_color: parse_color(Keyword.get(opts, :filled_color)),
        empty_color: parse_color(Keyword.get(opts, :empty_color)),
        animation_color: parse_color(Keyword.get(opts, :animation_color)),
        show_percent: Keyword.get(opts, :show_percent, true),
        kitt_width: Keyword.get(opts, :kitt_width, 3),
        speed: speed,
        max_iterations: max_iterations,
        duration: duration
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    if global.verbose do
      Enum.each(0..19, fn f ->
        frame =
          ABComp.render_frame(value, max, f, bar_opts)
          |> Alaja.Buffer.to_iodata()
          |> IO.iodata_to_binary()

        IO.puts(frame)
      end)
    else
      ABComp.run(value, max, bar_opts, GlobalOpts.to_keyword(global))
    end
  end

  defp parse_type("kitt"), do: :kitt
  defp parse_type("pulse"), do: :pulse
  defp parse_type("wave"), do: :wave
  defp parse_type("rainbow"), do: :rainbow
  defp parse_type(_), do: :spinner

  # Animation loop and frame-count math live in
  # `Alaja.Components.AnimatedBar.run/4` (backend). The CLI is a thin
  # wrapper that parses argv and delegates.

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Alaja.CLI.Color.parse(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
