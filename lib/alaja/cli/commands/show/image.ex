defmodule Alaja.CLI.Commands.Show.Image do
  @moduledoc "`alaja image` — Display images in terminal."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Header, Separator, Table}
  alias Alaja.ImageRenderer

  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          path: :string,
          width: :integer,
          height: :integer,
          protocol: :string,
          to_ascii_art: :boolean,
          ascii_chars: :string,
          ascii_color: :boolean,
          ascii_saturation: :float,
          ascii_style: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      path = Keyword.get(opts, :path)
      render_image(path, opts, global)
    end
  end

  defp render_image(path, opts, global) do
    cond do
      is_nil(path) or path == "" ->
        help()

      not File.exists?(path) ->
        IO.puts(:stderr, "Error: File not found: #{path}")
        :ok

      global.raw and (global.pos_x == 0 and global.pos_y == 0) ->
        IO.puts(:stderr, "Error: --raw requires both --pos-x and --pos-y")
        :ok

      Keyword.get(opts, :to_ascii_art, false) ->
        render_ascii(path, opts, global)

      true ->
        render(path, opts, global)
    end
  end

  defp render_ascii(path, opts, global) do
    if global.raw do
      IO.write("\e[#{global.pos_y + 1};#{global.pos_x + 1}H")
    end

    render_opts = [
      width: Keyword.get(opts, :width, 40),
      height: Keyword.get(opts, :height, 0),
      ascii_style: parse_ascii_style(Keyword.get(opts, :ascii_style)),
      ascii_chars: Keyword.get(opts, :ascii_chars),
      ascii_color: Keyword.get(opts, :ascii_color, true),
      ascii_saturation: Keyword.get(opts, :ascii_saturation, 1.0)
    ]

    case ImageRenderer.render_ascii_art(path, render_opts) do
      :ok -> :ok
      :unsupported -> IO.puts(:stderr, "Could not render ASCII art (install python3 + Pillow)")
    end
  end

  defp parse_ascii_style(nil), do: nil

  defp parse_ascii_style(s) do
    case Alaja.Helpers.safe_string_to_atom(s) do
      {:ok, atom} -> atom
      {:error, _} -> nil
    end
  end

  @dialyzer {:nowarn_function, {:render, 3}}
  defp render(path, opts, global) do
    if global.raw do
      IO.write("\e[#{global.pos_y + 1};#{global.pos_x + 1}H")
    end

    render_opts =
      [
        align: global.align,
        width: Keyword.get(opts, :width, 40),
        height: Keyword.get(opts, :height, 20)
      ]
      |> maybe_put(:protocol, protocol_opt(opts))

    case ImageRenderer.render_file(path, render_opts) do
      :ok -> :ok
      :unsupported -> IO.puts(:stderr, "Terminal does not support image rendering")
      {:error, reason} -> IO.puts(:stderr, "Error: #{inspect(reason)}")
    end
  end

  defp protocol_opt(opts) do
    case Keyword.get(opts, :protocol) do
      nil ->
        nil

      p ->
        case Alaja.Helpers.safe_string_to_atom(p) do
          {:ok, atom} -> atom
          {:error, _} -> nil
        end
    end
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)

  @spec help() :: :ok
  def help do
    Header.print("Alaja Image", subtitle: "Display images in the terminal", size: :small)
    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display an image file in the terminal. Supports multiple rendering")
    IO.puts("  protocols (kitty, iterm2, sixel, ascii). Automatically detects the")
    IO.puts("  best protocol, or you can force one with --protocol.")
    IO.puts("  Also supports ASCII art conversion with --to-ascii-art.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja image --path <file> [options]")
    IO.puts("  alaja image --path <file> --to-ascii-art [options]")
    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--path FILE", "string", "", "", "Path to the image file (required)"],
        ["--width N", "integer", "1+", "40", "Target width in terminal cells"],
        ["--height N", "integer", "1+", "auto", "Target height in terminal cells"],
        [
          "--protocol TYPE",
          "string",
          "kitty, iterm2, sixel, ascii",
          "auto",
          "Force a specific rendering protocol"
        ],
        [
          "--to-ascii-art",
          "boolean",
          "",
          "false",
          "Convert image to ASCII art (PNG natively; other formats need ImageMagick)"
        ],
        [
          "--ascii-style TYPE",
          "string",
          "blocks, detailed, simple, braille",
          "blocks",
          "Character set preset for ASCII art"
        ],
        [
          "--ascii-chars CHARS",
          "string",
          "",
          "",
          "Custom character string (overrides --ascii-style)"
        ],
        ["--ascii-color BOOL", "boolean", "", "true", "Colorize ASCII art output"],
        [
          "--ascii-saturation N",
          "float",
          "0.0-1.0",
          "1.0",
          "Color saturation (0=grayscale, 1=full color)"
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
        ["alaja image --path photo.png", "Basic image display"],
        ["alaja image --path screenshot.jpg --width 60 --height 30", "Custom dimensions"],
        ["alaja image --path logo.png --protocol ascii", "Force ASCII rendering"],
        [
          "alaja image --path banner.png --protocol kitty --width 80",
          "Force kitty protocol"
        ],
        [
          "alaja image --path icon.png --width 20 --height 10 --raw --pos-x 10 --pos-y 5",
          "Raw positioning"
        ],
        [
          "alaja image --path preview.png --width 50 --height 25 --box --box-title \"Image\" --box-border rounded --box-color \"#00B4D8\"",
          "With box wrapper"
        ],
        [
          "alaja image --path photo.png --to-ascii-art --width 60",
          "ASCII art conversion"
        ],
        [
          "alaja image --path photo.png --to-ascii-art --ascii-style detailed --ascii-color true --ascii-saturation 0.5",
          "ASCII art with custom style and saturation"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
  end
end
