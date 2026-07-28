defmodule Alaja.Components.Table.Borders do
  @moduledoc false

  alias Alaja.Components.Table.Theme

  @border_chars %{
    normal: %{
      top_left: "┌",
      top_right: "┐",
      bottom_left: "└",
      bottom_right: "┘",
      horizontal: "─",
      vertical: "│",
      cross: "┼",
      top_t: "┬",
      bottom_t: "┴",
      left_t: "├",
      right_t: "┤"
    },
    rounded: %{
      top_left: "╭",
      top_right: "╮",
      bottom_left: "╰",
      bottom_right: "╯",
      horizontal: "─",
      vertical: "│",
      cross: "┼",
      top_t: "┬",
      bottom_t: "┴",
      left_t: "├",
      right_t: "┤"
    },
    double: %{
      top_left: "╔",
      top_right: "╗",
      bottom_left: "╚",
      bottom_right: "╝",
      horizontal: "═",
      vertical: "║",
      cross: "╬",
      top_t: "╦",
      bottom_t: "╩",
      left_t: "╠",
      right_t: "╣"
    },
    none: %{
      top_left: "",
      top_right: "",
      bottom_left: "",
      bottom_right: "",
      horizontal: "",
      vertical: "",
      cross: "",
      top_t: "",
      bottom_t: "",
      left_t: "",
      right_t: ""
    }
  }

  @spec get_border_chars(:custom | :rounded | :double | :none | atom(), map() | term()) ::
          map()
  def get_border_chars(:custom, custom_borders) when is_map(custom_borders) do
    Map.merge(@border_chars.normal, custom_borders)
  end

  def get_border_chars(:rounded, _custom), do: @border_chars.rounded
  def get_border_chars(:double, _custom), do: @border_chars.double
  def get_border_chars(:none, _custom), do: @border_chars.none
  def get_border_chars(_style, _custom), do: @border_chars.normal

  @spec build_top_border(list(), Alaja.Components.Table.Config.t()) :: list()
  def build_top_border(_widths, config) do
    border_chars = config.border_chars
    border_color = config.border_color
    segments = config.horizontal_segments

    top_left = Theme.render_formatted(border_chars.top_left, border_color, config.border_effects)
    top_t = Theme.render_formatted(border_chars.top_t, border_color, config.border_effects)

    top_right =
      Theme.render_formatted(border_chars.top_right, border_color, config.border_effects)

    [
      config.offset_str,
      top_left,
      Enum.intersperse(segments, top_t),
      top_right,
      "\n"
    ]
  end

  @spec build_header_separator(list(), Alaja.Components.Table.Config.t()) :: list()
  def build_header_separator(_widths, config) do
    border_chars = config.border_chars
    border_color = config.border_color
    segments = config.horizontal_segments

    left_t = Theme.render_formatted(border_chars.left_t, border_color, config.border_effects)
    cross = Theme.render_formatted(border_chars.cross, border_color, config.border_effects)
    right_t = Theme.render_formatted(border_chars.right_t, border_color, config.border_effects)

    [
      config.offset_str,
      left_t,
      Enum.intersperse(segments, cross),
      right_t,
      "\n"
    ]
  end

  @spec build_bottom_border(list(), Alaja.Components.Table.Config.t()) :: list()
  def build_bottom_border(_widths, config) do
    border_chars = config.border_chars
    border_color = config.border_color
    segments = config.horizontal_segments

    bottom_left =
      Theme.render_formatted(border_chars.bottom_left, border_color, config.border_effects)

    bottom_t = Theme.render_formatted(border_chars.bottom_t, border_color, config.border_effects)

    bottom_right =
      Theme.render_formatted(border_chars.bottom_right, border_color, config.border_effects)

    [
      config.offset_str,
      bottom_left,
      Enum.intersperse(segments, bottom_t),
      bottom_right,
      "\n"
    ]
  end

  @spec print_top_border(list(), Alaja.Components.Table.Config.t()) :: :ok
  def print_top_border(widths, config) do
    print_border_line(
      widths,
      config.border_chars.top_left,
      config.border_chars.top_right,
      config.border_chars.horizontal,
      config.border_chars.top_t,
      config
    )
  end

  @spec print_bottom_border(list(), Alaja.Components.Table.Config.t()) :: :ok
  def print_bottom_border(widths, config) do
    print_border_line(
      widths,
      config.border_chars.bottom_left,
      config.border_chars.bottom_right,
      config.border_chars.horizontal,
      config.border_chars.bottom_t,
      config
    )
  end

  @spec print_header_separator(list(), Alaja.Components.Table.Config.t()) :: :ok
  def print_header_separator(widths, config) do
    print_border_line(
      widths,
      config.border_chars.left_t,
      config.border_chars.right_t,
      config.border_chars.horizontal,
      config.border_chars.cross,
      config
    )
  end

  @spec print_border_line(
          list(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          Alaja.Components.Table.Config.t()
        ) ::
          :ok
  def print_border_line(_widths, left, right, _horizontal, sep, config) do
    sep_colored = Theme.render_formatted(sep, config.border_color, config.border_effects)

    middle = Enum.intersperse(config.horizontal_segments, sep_colored) |> IO.iodata_to_binary()

    left_formatted = Theme.render_formatted(left, config.border_color, config.border_effects)
    right_formatted = Theme.render_formatted(right, config.border_color, config.border_effects)
    line = "#{config.offset_str}#{left_formatted}#{middle}#{right_formatted}"

    IO.puts(line)
  end
end
