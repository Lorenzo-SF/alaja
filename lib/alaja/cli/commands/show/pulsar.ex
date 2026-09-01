defmodule Alaja.CLI.Commands.Show.Pulsar do
  @moduledoc """
  `alaja pulsar` — Display pulsar/radar animation with gradient wave effect.

  Creates a rectangular animation with text in the center surrounded by
  pulsing characters that create a radar/wave effect.

  This CLI is a thin wrapper. All animation logic lives in
  `Alaja.Components.Pulsar.run/3`.
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.CLI.Parser
  alias Alaja.Components.Pulsar

  @help_data [
    title: "Alaja Pulsar",
    subtitle: "Pulsar/radar animation with gradient wave effect",
    usage:
      "alaja pulsar <text> [--width N] [--height N] [--chars C] [--colors C|C|C] [--color C] [--speed N] [--align left|center|right] [--direction in|out] [--content-position-x N] [--content-position-y N] [--content-type text|image] [--image-path FILE]",
    description: """
    Renders a pulsar/radar animation. The text is drawn in the center
    surrounded by a pulsing gradient ring/box. Useful as a long-running
    indicator; Ctrl+C to cancel.
    """,
    options: [
      {:text, :string, nil, "Text drawn in the center (or positional arg)"},
      {:width, :integer, 40, "Width in cells"},
      {:height, :integer, 7, "Height in rows"},
      {:colors, :string, nil,
       "List of colors separated by `|` (NOT commas; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: theme:primary|theme:secondary|rgb:255,0,0"},
      {:color, :string, nil, "Single color for the pulse"},
      {:speed, :integer, 100, "Milliseconds between frames (default: 100 = 10 fps)"},
      {:align, :string, "center", "Text alignment"},
      {:chars, :string, "░▒▓█", "Custom pulse ramp chars (default: ░▒▓█)"},
      {:direction, :string, "in", "Pulse direction: in (collapse) or out (expand)"},
      {:"content-position-x", :integer, nil, "Override content X position"},
      {:"content-position-y", :integer, nil, "Override content Y position"},
      {:content_type, :string, "text", "Content type: text or image"},
      {:image_path, :string, nil, "Path to image (when content_type=image)"},
      {:duration, :integer, nil, "Stop automatically after N ms (nil = run until Ctrl+C)"}
    ],
    examples: [
      {"Quick 3s demo", "alaja pulsar \"Alaja\" --duration 3000"},
      {"Multicolour radar",
       "alaja pulsar \"Deploy\" --width 50 --height 9 --colors hex:00ffff|hex:ff00ff --duration 2000"},
      {"Long indicator (Ctrl+C to stop)", "alaja pulsar \"Working...\" --color cyan"},
      {"Bigger frame", "alaja pulsar \"v3.0\" --width 80 --height 12 --duration 4000"},
      {"Collapse direction", "alaja pulsar \"In\" --direction in --duration 2000"},
      {"Custom pulse characters", "alaja pulsar \"Hi\" --chars \"▒░▒░\" --duration 2000"}
    ]
  ]

  @doc "Runs the `alaja pulsar` command — renders the radar/pulse animation for `--duration` ms."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches:
          [
            text: :string,
            width: :integer,
            height: :integer,
            colors: :string,
            color: :string,
            speed: :integer,
            align: :string,
            chars: :string,
            direction: :string,
            content_type: :string,
            image_path: :string,
            duration: :integer
          ] ++
            [
              {String.to_atom("content-position-x"), :integer},
              {String.to_atom("content-position-y"), :integer}
            ]
      )

    if global.help do
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

    pulse_chars = parse_pulse_chars(opts)
    colors_result = parse_colors(opts)

    case colors_result do
      {:ok, colors} ->
        direction = parse_direction(Keyword.get(opts, :direction, "out"))
        align = Parser.parse_align(Keyword.get(opts, :align, "center"))
        content_type = parse_content_type(Keyword.get(opts, :content_type, "text"))
        content_x = Keyword.get(opts, :"content-position-x")
        content_y = Keyword.get(opts, :"content-position-y")

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
          duration: Keyword.get(opts, :duration),
          text: text
        ]

        if global.verbose do
          print_verbose_frames(text, pulsar_opts)
        else
          Pulsar.run(text, pulsar_opts, GlobalOpts.to_keyword(global || %GlobalOpts{}))
        end

      {:error, error_msg} ->
        IO.puts(:stderr, "Error: #{error_msg}")
        exit({:shutdown, 1})
    end
  end

  # Static frame dump (no animation loop). Lives in the CLI because it is
  # purely a `--verbose` smoke helper — it is not a reusable component
  # feature.
  defp print_verbose_frames(text, pulsar_opts) do
    Enum.each(0..19, fn frame ->
      frame_output =
        text
        |> Pulsar.render_frame(frame, pulsar_opts)
        |> Alaja.Buffer.to_iodata()

      IO.puts(frame_output)
      IO.puts("")
    end)
  end

  # CLI-side argument parsing helpers (kept inline — they are 4 lines each
  # and `Data` was a thin wrapper around them).
  defp parse_pulse_chars(opts) do
    case Keyword.get(opts, :chars) do
      nil ->
        ["░", "▒", "▓", "█"]

      "" ->
        ["░", "▒", "▓", "█"]

      chars_str ->
        chars_str
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp parse_colors(opts) do
    case Keyword.get(opts, :colors) || Keyword.get(opts, :color) do
      nil -> {:ok, [{0, 180, 216}]}
      colors_str -> Alaja.CLI.Color.parse_list(colors_str)
    end
  end

  defp parse_direction("in"), do: :out
  defp parse_direction("out"), do: :in

  defp parse_direction(other) do
    IO.puts(:stderr, "Error: --direction must be 'in' or 'out', got '#{other}'")
    exit({:shutdown, 1})
  end

  defp parse_content_type("text"), do: :text
  defp parse_content_type("image"), do: :image

  defp parse_content_type(other) do
    IO.puts(:stderr, "Error: --content-type must be 'text' or 'image', got '#{other}'")
    exit({:shutdown, 1})
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
