defmodule Alaja.Components.Gradient do
  @moduledoc """
  Gradient-colored text rendering.

  Provides functions to apply color gradients to text, supporting both
  foreground and background gradients, vertical and horizontal directions,
  and multi-color gradients.

  ## Usage

      # Two-color gradient
      result = Alaja.Components.Gradient.apply_gradient_text("Hello", {255, 0, 0}, {0, 0, 255})

      # Multi-color gradient
      colors = [{255, 0, 0}, {255, 255, 0}, {0, 255, 0}]
      result = Alaja.Components.Gradient.apply_multicolor_text("Hello", colors)

      # Background gradient
      result = Alaja.Components.Gradient.render("Hello\nWorld", [
        from: "#FF0000", to: "#0000FF", bg: true, text_color: {255, 255, 255}
      ])
  """

  alias Alaja.CLI.Parser
  alias Pote.Gradients

  @doc """
  Renders text with a gradient applied, returning an ANSI string.

  Accepts the same options as the CLI, making it suitable for both
  programmatic use and CLI delegation.

  ## Options

    * `:from` — start color string (default: "#FF0000")
    * `:to` — end color string (default: "#0000FF")
    * `:colors` — pipe-separated multi-color gradient
    * `:direction` — `:left_to_right`, `:right_to_left`, `:up_to_down`, `:down_to_up`
    * `:bg` — apply to background instead of foreground
    * `:text_color` — text color when using `:bg` mode
  """
  @spec render(String.t(), keyword()) :: String.t() | {:error, String.t()}
  def render(text, opts \\ []) do
    direction = Keyword.get(opts, :direction, :left_to_right)
    bg = Keyword.get(opts, :bg, false)
    text_color = Keyword.get(opts, :text_color)
    colors_str = Keyword.get(opts, :colors)
    lines = split_lines(text)

    if direction in [:up_to_down, :down_to_up] do
      render_vertical_gradient(lines, opts, colors_str, direction, bg, text_color)
    else
      render_horizontal_gradient(lines, opts, colors_str, bg, text_color)
    end
  end

  @doc """
  Applies a simple two-color gradient to text.

  Uses Pote.Gradients internally. Returns iodata suitable for direct
  `IO.write` or `Alaja.Printer.print_raw/2`.
  """
  @spec apply_gradient_text(
          String.t(),
          {integer(), integer(), integer()},
          {integer(), integer(), integer()},
          keyword()
        ) :: iodata()
  def apply_gradient_text(text, from, to, opts \\ []) do
    direction = Keyword.get(opts, :direction, :left_to_right)
    bg = Keyword.get(opts, :bg, false)
    text_color = Keyword.get(opts, :text_color)

    if bg do
      Gradients.apply_bg_to_text(text, from, to, text_color || {255, 255, 255})
    else
      Gradients.apply_to_text(text, from, to, direction)
    end
  end

  @doc """
  Applies a multi-color gradient to text, one color step per character.

  Returns the ANSI-formatted string with reset appended.
  """
  @spec apply_multicolor_text(String.t(), [{integer(), integer(), integer()}], keyword()) ::
          String.t()
  def apply_multicolor_text(text, color_steps, opts \\ []) do
    bg = Keyword.get(opts, :bg, false)
    text_color = Keyword.get(opts, :text_color)
    chars = String.graphemes(text)

    result =
      Enum.map_join(Enum.with_index(chars), fn {char, i} ->
        color_idx = min(i, length(color_steps) - 1)
        color = Enum.at(color_steps, color_idx)
        apply_char(char, color, bg, text_color)
      end)

    "#{result}#{Alaja.ANSI.reset_attributes()}"
  end

  @doc """
  Parses two color strings into RGB tuples.
  """
  @spec parse_from_to_colors(String.t(), String.t()) :: [{integer(), integer(), integer()}]
  def parse_from_to_colors(from_str \\ "hex:ff0000", to_str \\ "hex:0000ff") do
    with {:ok, from} <- Alaja.CLI.Color.parse(from_str),
         {:ok, to} <- Alaja.CLI.Color.parse(to_str) do
      [from, to]
    else
      _ -> [{255, 0, 0}, {0, 0, 255}]
    end
  end

  @doc """
  Splits text into lines, handling both `\\r\\n` and `\\n`.
  """
  @spec split_lines(String.t()) :: [String.t()]
  def split_lines(text) do
    text
    |> String.split(~r{[\r\n]+}, trim: false)
    |> Enum.flat_map(fn line -> String.split(line, "\n") end)
  end

  # ── Rendering helpers (public for reuse) ─────────────────────────────

  @doc false
  def render_vertical_gradient(lines, opts, colors_str, direction, bg, text_color) do
    colors =
      case colors_str do
        nil ->
          parse_from_to_colors(
            Keyword.get(opts, :from, "#FF0000"),
            Keyword.get(opts, :to, "#0000FF")
          )

        str ->
          case Parser.parse_color_list(str) do
            {:ok, colors_list} when length(colors_list) >= 2 -> colors_list
            _ -> parse_from_to_colors()
          end
      end

    apply_vertical_gradient(lines, colors, direction, bg, text_color)
  end

  @doc false
  def render_horizontal_gradient(lines, opts, colors_str, bg, text_color) do
    case colors_str do
      nil ->
        [from, to] =
          parse_from_to_colors(
            Keyword.get(opts, :from, "#FF0000"),
            Keyword.get(opts, :to, "#0000FF")
          )

        apply_gradient_text(Enum.join(lines, "\n"), from, to,
          direction: :left_to_right,
          bg: bg,
          text_color: text_color
        )

      str ->
        case Parser.parse_color_list(str) do
          {:ok, colors_list} when length(colors_list) >= 2 ->
            Enum.map_join(lines, "\n", &render_horizontal_line(&1, colors_list, bg, text_color)) <>
              Alaja.ANSI.reset_attributes()

          _ ->
            [from, to] =
              parse_from_to_colors(
                Keyword.get(opts, :from, "#FF0000"),
                Keyword.get(opts, :to, "#0000FF")
              )

            apply_gradient_text(Enum.join(lines, "\n"), from, to,
              direction: :left_to_right,
              bg: bg,
              text_color: text_color
            )
        end
    end
  end

  @doc false
  def render_horizontal_line(line, colors_list, bg, text_color) do
    steps = String.length(line)
    color_steps = Gradients.multicolor(colors_list, steps)
    apply_multicolor_text(line, color_steps, bg: bg, text_color: text_color)
  end

  @doc false
  def apply_vertical_gradient(lines, color_list, direction, bg, text_color) do
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

  @doc false
  def apply_char(char, color, false, _), do: "#{fg_code(color)}#{char}"

  def apply_char(char, color, true, tc) do
    "#{bg_code(color)}#{if tc, do: fg_code(tc), else: ""}#{char}"
  end

  @doc false
  def fg_code({r, g, b}), do: Alaja.ANSI.fg(r, g, b)

  @doc false
  def bg_code({r, g, b}), do: Alaja.ANSI.bg(r, g, b)
end
