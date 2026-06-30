defmodule Alaja.CLI.Commands.Show.AnimatedBar do
  @moduledoc "`alaja animated-bar` — Display animated progress bar."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.AnimatedBar, as: ABComp
  alias Alaja.Components.{Box, Header, Separator, Table}

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
        speed: speed
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    if global.verbose do
      Enum.each(0..19, fn f ->
        frame = ABComp.render_frame(value, max, f, bar_opts) |> IO.iodata_to_binary()
        IO.puts(frame)
      end)
    else
      run_animated(value, max, bar_opts, global)
    end
  end

  defp run_animated(value, max, bar_opts, global) do
    box_height = if global.box, do: 3, else: 1
    speed = Keyword.get(bar_opts, :speed, 100)

    frames = Stream.iterate(0, &(&1 + 1))

    Enum.each(frames, fn position ->
      frame = ABComp.render_frame(value, max, position, bar_opts) |> IO.iodata_to_binary()

      wrapped =
        if global.box do
          box_opts =
            []
            |> maybe_add(:title, global.box_title)
            |> maybe_add(:border, global.box_border)
            |> maybe_add(:border_color, global.box_color)

          Box.render(frame, box_opts) |> IO.iodata_to_binary()
        else
          frame
        end

      if position == 0 do
        IO.write(wrapped)
      else
        # Move cursor up box_height lines, then clear from cursor to end of
        # screen. The original code used \e[K which only clears the current
        # line; when the frame is taller than 1 line (e.g. with --box, which
        # adds a top and bottom border), previous-frame leftovers were
        # left behind. Using \e[J ensures everything below the moved cursor
        # is wiped clean.
        IO.write("\e[#{box_height}A\e[J#{wrapped}")
      end

      Process.sleep(speed)
    end)
  end

  defp parse_type("kitt"), do: :kitt
  defp parse_type("pulse"), do: :pulse
  defp parse_type("wave"), do: :wave
  defp parse_type("rainbow"), do: :rainbow
  defp parse_type(_), do: :spinner

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
  def help do
    Header.print("Alaja Animated Bar",
      subtitle: "Display animated progress bar",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display an animated progress bar with a static filled portion")
    IO.puts("  that shows a looping animation. Runs indefinitely until")
    IO.puts("  killed (Ctrl+C) or another message overwrites it.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja animated-bar <value> [options]")
    IO.puts("  alaja animated-bar --value N [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        [
          "<value>",
          "Yes*",
          "Current progress value (integer). Required unless --value is provided."
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--value N", "integer", "0+", "", "Current value (alternative to positional arg)"],
        ["--max N", "integer", "1+", "100", "Maximum value for the progress bar"],
        ["--label TEXT", "string", "", "", "Label text displayed alongside the bar"],
        [
          "--type TYPE",
          "string",
          "spinner, kitt, pulse, wave, rainbow",
          "spinner",
          "Animation style for the filled portion"
        ],
        ["--width N", "integer", "1+", "40", "Width of the bar in characters"],
        [
          "--filled-char CHAR",
          "string",
          "Any character",
          "▓",
          "Character for the filled portion"
        ],
        ["--empty-char CHAR", "string", "Any character", "░", "Character for the empty portion"],
        ["--filled-color COLOR", "string", "Any color format", "", "Color of the filled portion"],
        ["--empty-color COLOR", "string", "Any color format", "", "Color of the empty portion"],
        [
          "--animation-color COLOR",
          "string",
          "Any color format",
          "",
          "Color of the animation highlight (kitt type)"
        ],
        ["--speed N", "integer", "1+", "100", "Animation speed in milliseconds per frame"],
        ["--show-percent BOOL", "boolean", "", "true", "Show percentage next to the bar"],
        ["--kitt-width N", "integer", "1+", "3", "Width of the KITT scanner highlight"],
        [
          "--verbose",
          "boolean",
          "",
          "false",
          "Print 20 sample frames as text instead of animating"
        ]
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
        ["alaja animated-bar 50", "Basic animated bar (value 50 of 100)"],
        [
          "alaja animated-bar 75 --max 100 --label \"Uploading...\"",
          "With label and custom max"
        ],
        [
          "alaja animated-bar 60 --type kitt --animation-color red",
          "KITT scanner animation"
        ],
        [
          "alaja animated-bar 80 --filled-char \"█\" --empty-char \"─\" --filled-color green --empty-color gray --width 60",
          "Custom characters and colors"
        ],
        [
          "alaja animated-bar 30 --speed 50 --label \"Installing\"",
          "Fast animation"
        ],
        ["alaja animated-bar 50 --verbose", "Verbose mode (print sample frames)"],
        [
          "alaja animated-bar 45 --label \"Loading\" --filled-color \"#FF6B6B\" --box --box-title \"Progress\" --box-border double --box-color \"#FFE66D\"",
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
