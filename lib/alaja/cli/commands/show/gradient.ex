# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Alaja.CLI.Commands.Show.Gradient do
  @moduledoc "`alaja gradient` — Display gradient-colored text."

  alias Alaja.CLI.{GlobalOpts, Parser}
  alias Alaja.Components.{Header, Separator, Table}
  alias Alaja.Printer
  alias Pote.{Gradients, Orchestrator}

  @doc """
  Runs the gradient command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          from: :string,
          to: :string,
          colors: :string,
          direction: :string,
          bg: :boolean,
          text_color: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      case positional do
        [] -> help()
        lines -> render(Enum.join(lines, "\n"), opts, global)
      end
    end
  end

  defp render(text, opts, global) do
    direction =
      case Alaja.Helpers.safe_string_to_atom(Keyword.get(opts, :direction, "left_to_right")) do
        {:ok, atom} -> atom
        {:error, _} -> :left_to_right
      end

    bg = Keyword.get(opts, :bg, false)
    text_color = parse_color(Keyword.get(opts, :text_color))
    colors_str = Keyword.get(opts, :colors)
    lines = split_lines(text)

    result =
      if direction in [:up_to_down, :down_to_up] do
        render_vertical_gradient(lines, opts, colors_str, direction, bg, text_color)
      else
        render_horizontal_gradient(lines, opts, colors_str, bg, text_color)
      end

    case result do
      {:error, _} -> IO.puts(:stderr, "Invalid color format")
      output -> Printer.print_raw(output, printer_opts(global))
    end
  end

  defp render_vertical_gradient(lines, opts, colors_str, direction, bg, text_color) do
    colors =
      case colors_str do
        nil ->
          get_from_to_colors(opts)

        str ->
          case Parser.parse_color_list(str) do
            {:ok, colors_list} when length(colors_list) >= 2 -> colors_list
            _ -> get_from_to_colors(opts)
          end
      end

    apply_vertical_gradient(lines, colors, direction, bg, text_color)
  end

  defp render_horizontal_gradient(lines, opts, colors_str, bg, text_color) do
    case colors_str do
      nil ->
        apply_gradient(Enum.join(lines, "\n"), opts, :left_to_right, bg, text_color)

      str ->
        case Parser.parse_color_list(str) do
          {:ok, colors_list} when length(colors_list) >= 2 ->
            Enum.map_join(lines, "\n", &render_horizontal_line(&1, colors_list, bg, text_color)) <>
              Alaja.ANSI.reset_attributes()

          _ ->
            apply_gradient(Enum.join(lines, "\n"), opts, :left_to_right, bg, text_color)
        end
    end
  end

  defp render_horizontal_line(line, colors_list, bg, text_color) do
    steps = String.length(line)
    color_steps = Gradients.multicolor(colors_list, steps)
    apply_multicolor(line, color_steps, bg, text_color)
  end

  defp split_lines(text) do
    text
    |> String.split(~r{[\r\n]+}, trim: false)
    |> Enum.flat_map(fn line -> String.split(line, "\n") end)
  end

  defp get_from_to_colors(opts) do
    from_str = Keyword.get(opts, :from, "#FF0000")
    to_str = Keyword.get(opts, :to, "#0000FF")

    with {:ok, from} <- Orchestrator.parse_color(from_str),
         {:ok, to} <- Orchestrator.parse_color(to_str) do
      [from, to]
    else
      _ -> [{255, 0, 0}, {0, 0, 255}]
    end
  end

  defp apply_vertical_gradient(lines, color_list, direction, bg, text_color) do
    line_count = max(length(lines), 1)
    color_steps = Gradients.multicolor(color_list, line_count)

    color_steps =
      if direction == :down_to_up, do: Enum.reverse(color_steps), else: color_steps

    body =
      lines
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {line, idx} ->
        color = Enum.at(color_steps, min(idx, length(color_steps) - 1))

        if bg do
          tc = text_color || {255, 255, 255}
          "#{bg_code(color)}#{fg_code(tc)}#{line}"
        else
          "#{fg_code(color)}#{line}"
        end
      end)

    body <> Alaja.ANSI.reset_attributes()
  end

  defp apply_gradient(text, opts, direction, bg, text_color) do
    from_str = Keyword.get(opts, :from, "#FF0000")
    to_str = Keyword.get(opts, :to, "#0000FF")

    with {:ok, from} <- Orchestrator.parse_color(from_str),
         {:ok, to} <- Orchestrator.parse_color(to_str) do
      if bg do
        Gradients.apply_bg_to_text(text, from, to, text_color || {255, 255, 255})
      else
        Gradients.apply_to_text(text, from, to, direction)
      end
    else
      _ -> {:error, :invalid_color}
    end
  end

  defp apply_multicolor(text, color_steps, bg, text_color) do
    chars = String.graphemes(text)

    result =
      Enum.map_join(Enum.with_index(chars), fn {char, i} ->
        color_idx = min(i, length(color_steps) - 1)
        color = Enum.at(color_steps, color_idx)
        apply_char(char, color, bg, text_color)
      end)

    "#{result}#{Alaja.ANSI.reset_attributes()}"
  end

  defp apply_char(char, color, false, _), do: "#{fg_code(color)}#{char}"

  defp apply_char(char, color, true, tc) do
    "#{bg_code(color)}#{if tc, do: fg_code(tc), else: ""}#{char}"
  end

  defp fg_code({r, g, b}), do: Pote.Orchestrator.to_ansi({r, g, b})
  defp bg_code({r, g, b}), do: Pote.Orchestrator.to_ansi_bg({r, g, b})

  defp parse_color(nil), do: nil
  defp parse_color(s), do: Parser.parse_color_opt(s)

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc """
  Prints help for the gradient command.
  """
  @spec help() :: :ok
  def help do
    Header.print("Alaja Gradient", subtitle: "Display gradient-colored text", size: :small)
    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display text with a color gradient. Supports two-color gradients")
    IO.puts("  (from/to) or multi-color gradients. Can apply to foreground or")
    IO.puts("  background. Direction controls the gradient flow.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja gradient <text> --from COLOR --to COLOR [options]")
    IO.puts("  alaja gradient <text> --colors \"C1;C2;C3\" [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<text>", "Yes", "Text to apply the gradient to"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("COLOR OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        [
          "--from COLOR",
          "string",
          "Any color format",
          "#FF0000 (red)",
          "Start color of the gradient"
        ],
        [
          "--to COLOR",
          "string",
          "Any color format",
          "#0000FF (blue)",
          "End color of the gradient"
        ],
        [
          "--colors LIST",
          "string",
          "Semicolon-separated colors",
          "",
          "Multi-color gradient (overrides --from/--to). E.g.: \"red;orange;yellow;green;blue\""
        ],
        ["--bg", "boolean", "", "false", "Apply gradient to background instead of foreground"],
        [
          "--text-color COLOR",
          "string",
          "Any color format",
          "",
          "Text color when using --bg mode"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("DIRECTION OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        [
          "--direction DIR",
          "string",
          "left_to_right, right_to_left",
          "left_to_right",
          "Gradient direction"
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

    IO.puts(
      "# Basic two-color gradient\n  alaja gradient \"Hello World\" --from red --to blue\n\n# Hex colors with direction\n  alaja gradient \"Gradient\" --from \"#FF0000\" --to \"#00FF00\" --direction right_to_left\n\n# Multi-color rainbow gradient\n  alaja gradient \"Rainbow\" --colors \"red;orange;yellow;green;blue;purple\"\n\n# Background gradient with text color\n  alaja gradient \"Boxed\" --from \"#1a1a2e\" --to \"#16213e\" --bg --text-color white\n\n# Raw positioning\n  alaja gradient \"Styled\" --from cyan --to magenta --raw --pos-x 10 --pos-y 5\n\n# Verbose mode (get ANSI string)\n  alaja gradient \"Test\" --from red --to blue --verbose\n\n# With box wrapper\n  alaja gradient \"Fancy\" --from \"#FF6B6B\" --to \"#4ECDC4\" --box --box-title \"Gradient\" --box-border double --box-color \"#FFE66D\""
    )

    IO.puts("")
    :ok
  end
end
