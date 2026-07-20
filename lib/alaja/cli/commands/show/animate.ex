defmodule Alaja.CLI.Commands.Show.Animate do
  @moduledoc "`alaja animate` — Display animated spinners and indicators."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Animate, Header, Separator, Table}

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
  def help do
    Header.print("Alaja Animate",
      subtitle: "Display animated spinners and indicators",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display an animated spinner or indicator in the terminal.")
    IO.puts("  Supports multiple built-in animation types, custom characters,")
    IO.puts("  colors, duration, speed, and verbose preview mode.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja animate [options]")
    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        [
          "--type TYPE",
          "string",
          "spinner, dots, bar, moon, clock, pulse, kitt",
          "spinner",
          "Animation style"
        ],
        ["--duration N", "integer", "1+", "3", "Duration in seconds"],
        ["--text TEXT", "string", "", "Loading", "Text displayed next to the animation"],
        [
          "--color COLOR",
          "string",
          "Any color format",
          "",
          "Animation color. Semicolon-separated for gradients (e.g.: \"red;green;blue\")"
        ],
        [
          "--colors LIST",
          "string",
          "Semicolon-separated colors",
          "",
          "Same as --color, accepts multiple colors"
        ],
        ["--speed N", "integer", "1+", "100", "Speed in milliseconds per frame"],
        [
          "--chars CHARS",
          "string",
          "Comma-separated characters",
          "",
          "Custom frame characters (overrides --type)"
        ],
        ["--verbose", "boolean", "", "false", "Print all frames as text instead of animating"]
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
        ["alaja animate --type spinner --duration 3", "Basic spinner"],
        ["alaja animate --type kitt --text \"Scanning\"", "Kitt scanner effect"],
        [
          "alaja animate --type spinner --color \"red;green;blue\" --duration 5",
          "Colored spinner with gradient"
        ],
        [
          "alaja animate --type dots --text \"Processing...\" --speed 50 --duration 10",
          "Custom speed and text"
        ],
        [
          "alaja animate --chars \">,>>,>>>,>>,>\" --text \"Loading\" --speed 200",
          "Custom characters"
        ],
        ["alaja animate --type bar --duration 2 --verbose", "Verbose mode (print frames)"],
        [
          "alaja animate --type moon --text \"Waiting\" --speed 300 --duration 8",
          "Moon cycle animation"
        ],
        [
          "alaja animate --type pulse --text \"Downloading\" --color cyan --speed 150 --duration 6",
          "Pulse effect with custom color"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
  end
end
