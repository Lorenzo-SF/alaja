defmodule Alaja.CLI.Commands.Show.Pulsar do
  @moduledoc """
  `alaja pulsar` — Display pulsar/radar animation with gradient wave effect.

  Creates a rectangular animation with text in the center surrounded by
  pulsing characters that create a radar/wave effect.
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.Parser
  alias Alaja.Components.{Box, Header, Pulsar, Separator, Table}
  alias Alaja.ImageRenderer

  @default_pulse_chars ["░", "▒", "▓", "█"]

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

    pulse_chars = parse_pulse_chars(opts)
    colors_result = parse_colors(opts)

    case colors_result do
      {:ok, colors} ->
        direction = parse_direction(Keyword.get(opts, :direction, "out"))
        align = Parser.parse_align(Keyword.get(opts, :align, "center"))
        content_type = parse_content_type(Keyword.get(opts, :content_type, "text"))
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
          print_verbose_frames(text, pulsar_opts)
        else
          run_animation(text, pulsar_opts, global)
        end

      {:error, error_msg} ->
        IO.puts(:stderr, "Error: #{error_msg}")
        exit({:shutdown, 1})
    end
  end

  defp parse_pulse_chars(opts) do
    case Keyword.get(opts, :chars) || Keyword.get(opts, :pulse_chars) do
      nil -> @default_pulse_chars
      chars_str -> String.split(chars_str, ",") |> Enum.map(&String.trim/1)
    end
  end

  defp parse_colors(opts) do
    case Keyword.get(opts, :colors) || Keyword.get(opts, :color) do
      nil -> {:ok, [{0, 180, 216}]}
      colors_str -> parse_colors_list(colors_str)
    end
  end

  defp parse_colors_list(colors_str) do
    colors_str
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {color_str, idx}, {:ok, acc} ->
      case Pote.Orchestrator.parse_color(color_str) do
        {:ok, rgb} ->
          {:cont, {:ok, [rgb | acc]}}

        {:error, error_msg} ->
          {:halt, {:error, "Invalid color at position #{idx + 1}: '#{color_str}'. #{error_msg}"}}
      end
    end)
    |> case do
      {:ok, colors} -> {:ok, Enum.reverse(colors)}
      error -> error
    end
  end

  defp parse_direction("in"), do: :in
  defp parse_direction("out"), do: :out

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

  defp run_animation(text, pulsar_opts, global) do
    speed = Keyword.get(pulsar_opts, :speed, 100)
    width = Keyword.get(pulsar_opts, :width, 40)
    height = Keyword.get(pulsar_opts, :height, 7)
    content_type = Keyword.get(pulsar_opts, :content_type, :text)
    internal_align = Keyword.get(pulsar_opts, :align, :center)
    box_height = if global.box, do: height + 2, else: height

    # Calculate horizontal alignment padding.
    # Only apply padding if global.align differs from internal alignment.
    # If pulsar text is centered (internal_align = :center) and global.align = :center,
    # we don't add padding because the pulsar already handles centering internally.
    left_pad =
      if global.align == internal_align do
        0
      else
        calculate_left_padding(global.align, width)
      end

    IO.write(Alaja.ANSI.hide_cursor())

    case content_type do
      :image ->
        run_image_animation(text, pulsar_opts, global, speed, width, height, left_pad)

      :text ->
        run_text_animation(text, pulsar_opts, global, speed, box_height, left_pad)
    end
  end

  defp run_text_animation(text, pulsar_opts, global, speed, box_height, left_pad) do
    start_pos = calculate_start_pos(global, left_pad)

    if global.raw do
      IO.write(Alaja.ANSI.hide_cursor())
    end

    # Bail out early if the terminal cannot fit the pulsar — there's
    # no point animating into a region that overflows, the cursor-up
    # redraw would loop over already-overwritten lines and the
    # animation would visibly stick.
    {term_h, _term_w} =
      case :io.rows() do
        {:ok, h} -> {h, 80}
        _ -> {24, 80}
      end

    {_, start_y} = start_pos

    if start_y + box_height - 1 > term_h do
      IO.write(
        :stderr,
        "alaja pulsar: not enough vertical space (#{start_y + box_height - 1} > #{term_h}); aborting\n"
      )

      if global.raw do
        IO.write(Alaja.ANSI.show_cursor())
      end

      :ok
    else
      try do
        animate_loop(text, pulsar_opts, global, 0, speed, box_height, left_pad, start_pos)
      after
        if global.raw do
          IO.write(Alaja.ANSI.show_cursor())
        end
      end
    end
  end

  defp calculate_start_pos(global, _left_pad) do
    # Only used with --raw flag
    {global.pos_x + 1, global.pos_y + 1}
  end

  defp run_image_animation(text, pulsar_opts, global, speed, width, height, left_pad) do
    image_path = Keyword.get(pulsar_opts, :image_path)

    if is_nil(image_path) or image_path == "" do
      IO.puts(:stderr, "Error: --image-path is required when using --content-type image")
      exit({:shutdown, 1})
    end

    if not File.exists?(image_path) do
      IO.puts(:stderr, "Error: Image file not found: #{image_path}")
      exit({:shutdown, 1})
    end

    try do
      opts = %{width: width, height: height, left_pad: left_pad}
      image_animate_loop(text, pulsar_opts, global, image_path, 0, speed, opts)
    after
      IO.write(Alaja.ANSI.show_cursor())
    end
  end

  defp calculate_left_padding(align, content_width) do
    terminal_width =
      case :io.columns() do
        {:ok, w} -> w
        _ -> 80
      end

    available = terminal_width - content_width

    case align do
      :left -> 0
      :center -> max(0, div(available, 2))
      :right -> max(0, available)
    end
  end

  defp animate_loop(text, pulsar_opts, global, frame, speed, box_height, left_pad, start_pos) do
    frame_output = Pulsar.render_frame(text, frame, pulsar_opts)
    output = wrap_if_boxed(frame_output, global)

    # output is now iodata (Buffer.to_iodata result), safe to split by '\n'.
    padded_output =
      output
      |> IO.iodata_to_binary()
      |> String.split("\n")
      |> Enum.map_join("\n", fn line -> String.duplicate(" ", left_pad) <> line end)

    if global.raw do
      {start_x, start_y} = start_pos

      if frame == 0 do
        IO.write([Alaja.ANSI.hide_cursor(), Alaja.ANSI.move_to(start_x, start_y), padded_output])
      else
        IO.write([
          Alaja.ANSI.move_to(start_x, start_y),
          Alaja.ANSI.clear_line_down(),
          padded_output
        ])
      end
    else
      if frame == 0 do
        # Save cursor position before writing
        IO.write([Alaja.ANSI.save_cursor(), padded_output])
      else
        # Restore to saved position, clear down, write new frame
        IO.write([Alaja.ANSI.restore_cursor(), Alaja.ANSI.clear_line_down(), padded_output])
      end
    end

    :timer.sleep(speed)
    animate_loop(text, pulsar_opts, global, frame + 1, speed, box_height, left_pad, start_pos)
  end

  defp image_animate_loop(text, pulsar_opts, global, image_path, frame, speed, opts) do
    %{width: width, height: height, left_pad: left_pad} = opts

    case Pulsar.render_frame_pixels(image_path, frame, pulsar_opts) do
      {:ok, pixels} ->
        padded_pixels = apply_left_padding_pixels(pixels, left_pad)
        ImageRenderer.render(padded_pixels, width: width, height: height, align: :left)

        :timer.sleep(speed)
        image_animate_loop(text, pulsar_opts, global, image_path, frame + 1, speed, opts)

      {:error, reason} ->
        IO.puts(:stderr, "Error rendering image: #{reason}")
    end
  end

  defp apply_left_padding_pixels(pixels, 0), do: pixels

  defp apply_left_padding_pixels(pixels, left_pad) do
    padding_row = List.duplicate({0, 0, 0}, left_pad)
    Enum.map(pixels, fn row -> padding_row ++ row end)
  end

  defp wrap_if_boxed(frame_output, %{box: true} = global) do
    box_opts =
      []
      |> maybe_add(:title, global.box_title)
      |> maybe_add(:border, global.box_border)
      |> maybe_add(:border_color, global.box_color)

    frame_output
    |> Box.render(box_opts)
    |> Alaja.Buffer.to_iodata()
  end

  defp wrap_if_boxed(frame_output, _global) do
    Alaja.Buffer.to_iodata(frame_output)
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)

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
