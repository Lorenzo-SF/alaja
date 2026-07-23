defmodule Alaja.CLI.Commands.Show.Pulsar do
  @moduledoc """
  `alaja pulsar` — Display pulsar/radar animation with gradient wave effect.

  Creates a rectangular animation with text in the center surrounded by
  pulsing characters that create a radar/wave effect.
  """

  alias Alaja.CLI.Commands.Show.Pulsar.{Data, Renderer}
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.Parser
  alias Alaja.Components.{Header, Separator, Table}

  @doc "Runs the `alaja pulsar` command — renders the radar/pulse animation for `--duration` ms."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          text: :string,
          width: :integer,
          height: :integer,
          pulse_chars: :string,
          colors: :string,
          color: :string,
          speed: :integer,
          align: :string,
          chars: :string,
          direction: :string,
          content_position_x: :integer,
          content_position_y: :integer,
          content_type: :string,
          image_path: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      text = Keyword.get(opts, :text) || Enum.join(positional, " ")

      if text == "" do
        help()
      else
        run_pulsar(text, opts, global)
      end
    end
  end

  defp run_pulsar(text, opts, global) do
    width = Keyword.get(opts, :width, 40)
    height = Keyword.get(opts, :height, 7)
    speed = Keyword.get(opts, :speed, 100)

    pulse_chars = Data.parse_pulse_chars(opts)
    colors_result = Data.parse_colors(opts)

    case colors_result do
      {:ok, colors} ->
        direction = Data.parse_direction(Keyword.get(opts, :direction, "out"))
        align = Parser.parse_align(Keyword.get(opts, :align, "center"))
        content_type = Data.parse_content_type(Keyword.get(opts, :content_type, "text"))
        content_x = Keyword.get(opts, :content_position_x)
        content_y = Keyword.get(opts, :content_position_y)

        pulsar_opts = [
          width: width,
          height: height,
          pulse_chars: pulse_chars,
          colors: colors,
          speed: speed,
          align: align,
          direction: direction,
          content_type: content_type,
          content_position_x: content_x,
          content_position_y: content_y,
          image_path: Keyword.get(opts, :image_path),
          text: text
        ]

        if global.verbose do
          Renderer.print_verbose_frames(text, pulsar_opts)
        else
          Renderer.run_animation(text, pulsar_opts, global)
        end

      {:error, error_msg} ->
        IO.puts(:stderr, "Error: #{error_msg}")
        exit({:shutdown, 1})
    end
  end

  @spec help() :: :ok
  def help do
    Header.print("Alaja Pulsar",
      subtitle: "Pulsar/radar animation with gradient wave effect",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display a rectangular animation with text in the center surrounded by")
    IO.puts("  pulsing characters that create a radar/wave effect.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja pulsar <text> [options]")
    IO.puts("  alaja pulsar --text <text> [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<text>", "Yes*", "Text to display in the center (unless --text is used)"],
        ["--text TEXT", "Yes*", "Text to display (alternative to positional arg)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--width N", "integer", "10+", "40", "Width of the pulsar area in characters"],
        ["--height N", "integer", "3+", "7", "Height of the pulsar area in lines"],
        ["--speed N", "integer", "1+", "100", "Animation speed in milliseconds per frame"],
        [
          "--align TYPE",
          "string",
          "left, center, right",
          "center",
          "Text alignment within the pulsar"
        ],
        [
          "--direction DIR",
          "string",
          "in, out",
          "out",
          "Wave direction: out (center to edge) or in (edge to center)"
        ],
        [
          "--colors LIST",
          "string",
          "format:value;...",
          "",
          "Gradient colors. Format: hex:FF0000;rgb:255,0,0;hsl:120,50,50"
        ],
        [
          "--chars CHARS",
          "string",
          "Comma-separated chars",
          "░,▒,▓,█",
          "Characters for pulse effect"
        ],
        [
          "--content-position-x N",
          "integer",
          "0+",
          "nil",
          "X position for content within pulsar (nil = auto centered)"
        ],
        [
          "--content-position-y N",
          "integer",
          "0+",
          "nil",
          "Y position for content within pulsar (nil = auto centered)"
        ],
        ["--content-type TYPE", "string", "text, image", "text", "Content type: text or image"],
        [
          "--image-path PATH",
          "string",
          "",
          "",
          "Path to image (required with --content-type image)"
        ],
        ["--verbose", "boolean", "", "false", "Print 20 sample frames as static text"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("COLOR FORMATS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Format", "Example"],
      rows: [
        ["hex:RRGGBB", "hex:FF0000"],
        ["rgb:R,G,B", "rgb:255,0,0"],
        ["argb:A,R,G,B", "argb:255,255,0,0"],
        ["hsl:H,S,L", "hsl:120,50,50"],
        ["hsv:H,S,V", "hsv:120,100,100"],
        ["cmyk:C,M,Y,K", "cmyk:100,0,50,0"],
        ["hwb:H,W,B", "hwb:120,0.2,0.3"],
        ["xterm:N", "xterm:202"],
        ["theme:NAME", "theme:primary"],
        ["#RRGGBB", "#FF0000"]
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
        ["alaja pulsar \"Scanning\"", "Basic pulsar with default settings"],
        ["alaja pulsar \"Processing\" --width 50 --height 9", "Custom size"],
        [
          "alaja pulsar \"Complete\" --colors \"hex:FF6B6B;hex:FFE66D;hex:4ECDC4\"",
          "With custom colors"
        ],
        ["alaja pulsar \"Ready\" --chars \".oO*\"", "Custom pulse characters"],
        ["alaja pulsar \"Loading\" --speed 50", "Fast animation"],
        [
          "alaja pulsar \"Deploying\" --box --box-title \"Status\" --box-border double",
          "With box wrapper"
        ],
        [
          "alaja pulsar \"Success\" --direction in --colors \"rgb:0,255,0;rgb:0,255,255\"",
          "Inward wave direction"
        ],
        [
          "alaja pulsar \"Offset\" --content-position-x 5 --content-position-y 2",
          "Content offset"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
  end
end
