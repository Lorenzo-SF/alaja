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
      {:animation_color, :string, nil, "Color of the moving animation cells (all types except rainbow)"},
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
  alias Alaja.Components.Box

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
    max_frames = compute_max_frames(duration, speed, max_iterations)

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
        max_frames: max_frames
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
      run_animated(value, max, bar_opts, global)
    end
  end

  defp run_animated(value, max, bar_opts, global) do
    box_height = if global.box, do: 3, else: 1
    speed = Keyword.get(bar_opts, :speed, 100)
    max_frames = Keyword.get(bar_opts, :max_frames, 100_000)
    use_abs = global.raw || global.pos_x > 0 || global.pos_y > 0

    state = %{
      value: value,
      max: max,
      speed: speed,
      bar_opts: bar_opts,
      global: global,
      box_height: box_height,
      use_abs: use_abs,
      start_x: global.pos_x + 1,
      start_y: global.pos_y + 1
    }

    # Guard against running the redraw loop in a terminal that cannot
    # fit the bar (or boxed bar). Without this check, the cursor-up
    # escape (\e[NA) used to clear the previous frame would walk past
    # row 1 and start wiping shell history / scrollback above, visibly
    # destroying unrelated content. Bail out cleanly with a stderr
    # note so the user can resize or scroll before retrying.
    term_h =
      case :io.rows() do
        {:ok, h} -> h
        _ -> 24
      end

    if box_height > term_h do
      IO.write(
        :stderr,
        "alaja animated-bar: not enough vertical space (#{box_height} > #{term_h}); aborting\n"
      )

      :ok
    else
      if state.use_abs do
        IO.write(Alaja.ANSI.hide_cursor())
      end

      frames = Stream.iterate(0, &(&1 + 1)) |> Stream.take(max_frames)
      Enum.each(frames, &animate_bar_frame(&1, state))

      if state.use_abs do
        IO.write(Alaja.ANSI.show_cursor())
      end
    end
  end

  defp animate_bar_frame(position, state) do
    frame =
      ABComp.render_frame(state.value, state.max, position, state.bar_opts)
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()

    wrapped = wrap_bar_frame(frame, state.global)

    if state.use_abs do
      IO.write([
        Alaja.ANSI.move_to(state.start_x, state.start_y),
        Alaja.ANSI.clear_line_down(),
        wrapped
      ])
    else
      write_bar_frame_relative(wrapped, position, state.box_height)
    end

    Process.sleep(state.speed)
  end

  defp wrap_bar_frame(frame, global) do
    if global.box do
      box_opts =
        []
        |> maybe_add(:title, global.box_title)
        |> maybe_add(:border, global.box_border)
        |> maybe_add(:border_color, global.box_color)

      Box.render(frame, box_opts)
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()
    else
      frame
    end
  end

  defp write_bar_frame_relative(wrapped, 0, _box_height), do: IO.write(wrapped)

  defp write_bar_frame_relative(wrapped, _position, box_height) do
    IO.write("\e[#{box_height}A\e[J#{wrapped}")
  end

  defp parse_type("kitt"), do: :kitt
  defp parse_type("pulse"), do: :pulse
  defp parse_type("wave"), do: :wave
  defp parse_type("rainbow"), do: :rainbow
  defp parse_type(_), do: :spinner

  # `--duration N` (ms) implies max_frames = ceil(duration / speed).
  # When no duration is set we return 100_000 to preserve the original
  # "animation runs forever" behaviour while still capping runaway loops
  # (the smoke tests pass `--duration 500` to terminate cleanly).
  # `--max-iterations` overrides the cap when provided.
  defp compute_max_frames(duration, _speed, nil) when is_nil(duration), do: 100_000

  defp compute_max_frames(duration_ms, speed, nil)
       when is_integer(duration_ms) and duration_ms > 0 do
    max(1, div(duration_ms + speed - 1, speed))
  end

  defp compute_max_frames(_duration, _speed, max_iter)
       when is_integer(max_iter) and max_iter > 0 do
    max_iter
  end

  defp compute_max_frames(_, _, _), do: 100_000

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Alaja.CLI.Color.parse(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
