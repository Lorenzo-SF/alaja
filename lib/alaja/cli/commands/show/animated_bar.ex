defmodule Alaja.CLI.Commands.Show.AnimatedBar do
  @moduledoc "`alaja animated-bar` — Display animated progress bar."

  @help_data [
    title: "Alaja Animated Bar",
    subtitle: "Display animated progress bar",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.AnimatedBar, as: ABComp
  alias Alaja.Components.{Box, Header, Separator, Table}

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
          kitt_width: :integer
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      value = parse_value(opts, positional)
      if is_nil(value), do: help(), else: render(value, opts, global)
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
    max_frames = compute_max_frames(duration, speed)

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
  defp compute_max_frames(nil, _speed), do: 100_000

  defp compute_max_frames(duration_ms, speed)
       when is_integer(duration_ms) and duration_ms > 0 do
    max(1, div(duration_ms + speed - 1, speed))
  end

  defp compute_max_frames(_, _), do: 100_000

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)

  @spec help() :: :ok
  def help, do: @help_data
end
