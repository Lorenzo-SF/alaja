defmodule Alaja.Components.Animate do
  @moduledoc """
  Animated spinners and indicators.

  Provides frame definitions, animation rendering, and KITT scanner
  effects for use in terminal spinners and progress indicators.

  ## Built-in animation types

    * `"spinner"` — Braille spinner characters
    * `"dots"` — Braille dot patterns
    * `"bar"` — Block bar animation
    * `"moon"` — Moon phase emoji cycle
    * `"clock"` — Clock face emoji cycle
    * `"pulse"` — Block pulse effect
    * `"kitt"` — KITT scanner effect (text-based)

  ## Usage

      # Get frames for a type
      frames = Alaja.Components.Animate.frames("spinner")

      # Render a single frame
      output = Alaja.Components.Animate.render_frame(frames, 0, "Loading", {0, 180, 216})

      # Parse color specifications
      colors = Alaja.Components.Animate.parse_colors("red", nil)
  """

  @frames %{
    "spinner" => ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
    "dots" => ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
    "bar" => ["▏", "▎", "▍", "▌", "▋", "▊", "▉", "█", "▉", "▊", "▋", "▌"],
    "moon" => ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"],
    "clock" => ["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"],
    "pulse" => ["█", "▓", "▒", "░", "▒", "▓"],
    "kitt" => ["█", "▓", "▒", "░"]
  }

  @doc "Returns the full frames map keyed by animation type name."
  @spec frames_map() :: %{String.t() => [String.t()]}
  def frames_map, do: @frames

  @doc """
  Returns the frame list for a given type, or the default spinner frames.

  If `chars_str` is provided (comma-separated custom characters), those
  override the built-in type frames.
  """
  @spec frames(String.t() | nil, String.t() | nil) :: [String.t()]
  def frames(type, chars_str \\ nil)

  def frames(type, nil), do: Map.get(@frames, type, Map.get(@frames, "spinner"))

  def frames(_type, chars_str) do
    chars_str |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  @doc """
  Parses color strings into RGB tuples.

  Accepts two sources (for backward compatibility): `color_str` and
  `colors_str`. Both are semicolon-separated lists of color names
  or hex values.
  """
  @spec parse_colors(String.t() | nil, String.t() | nil) :: [{integer(), integer(), integer()}]
  def parse_colors(color_str, colors_str) do
    cond do
      colors_str ->
        colors_str
        |> String.split(";")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&parse_one/1)
        |> Enum.reject(&is_nil/1)

      color_str ->
        color_str
        |> String.split(";")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&parse_one/1)
        |> Enum.reject(&is_nil/1)

      true ->
        []
    end
  end

  @doc """
  Renders a full animation sequence for a given duration.

  Writes output directly to stdout/stderr. In non-verbose mode, frames
  are rendered inline with `\\r` carriage return. In verbose mode, each
  frame is printed on its own line.

  ## Parameters

    * `frames` — list of frame characters
    * `duration` — total duration in seconds
    * `speed` — milliseconds per frame
    * `text` — label text displayed next to the animation
    * `base_color` — default RGB tuple for the animation
    * `verbose` — if true, print all frames as separate lines
    * `colors` — list of RGB tuples for gradient coloring
  """
  @spec run_animation(
          [String.t()],
          pos_integer(),
          pos_integer(),
          String.t(),
          {integer(), integer(), integer()},
          boolean(),
          [{integer(), integer(), integer()}]
        ) :: :ok
  def run_animation(frames, duration, speed, text, {cr, cg, cb}, verbose, colors) do
    iterations = duration * div(1000, speed)
    total = length(frames)

    if verbose do
      Enum.each(0..(iterations - 1), fn i ->
        fidx = rem(i, total)
        {fr, fg, fb} = frame_color(fidx, colors, {cr, cg, cb})

        IO.puts(
          "#{Pote.Orchestrator.to_ansi({fr, fg, fb})}#{Enum.at(frames, fidx)}#{Alaja.ANSI.reset_attributes()} #{text}"
        )
      end)
    else
      Enum.each(1..iterations, fn i ->
        fidx = rem(i, total)
        {fr, fg, fb} = frame_color(fidx, colors, {cr, cg, cb})

        IO.write(
          "\r\e[K  #{Pote.Orchestrator.to_ansi({fr, fg, fb})}#{Enum.at(frames, fidx)}#{Alaja.ANSI.reset_attributes()} #{text}..."
        )

        Process.sleep(speed)
      end)

      IO.write("\r\e[K")
    end
  end

  @doc """
  Renders a single animation frame as an ANSI string.

  Returns the ANSI string without writing to IO — useful for custom
  spinner loops or integration into other components.

  ## Example

      frames = Alaja.Components.Animate.frames("spinner")
      frame = Alaja.Components.Animate.render_frame(frames, 1, "Loading", nil, nil)
  """
  @spec render_frame(
          [String.t()],
          non_neg_integer(),
          String.t(),
          {integer(), integer(), integer()} | nil,
          [{integer(), integer(), integer()}] | nil
        ) :: String.t()
  def render_frame(frames, frame_index, text, base_color \\ nil, colors \\ []) do
    total = length(frames)
    fidx = rem(frame_index, total)
    {cr, cg, cb} = base_color || {0, 180, 216}
    {fr, fg, fb} = frame_color(fidx, colors, {cr, cg, cb})

    "\r\e[K  #{Pote.Orchestrator.to_ansi({fr, fg, fb})}#{Enum.at(frames, fidx)}#{Alaja.ANSI.reset_attributes()} #{text}..."
  end

  @doc """
  Renders the KITT scanner animation.

  Creates a KITT (Knight Rider) style scanning effect across the text.
  """
  @spec run_kitt(
          String.t(),
          pos_integer(),
          pos_integer(),
          {integer(), integer(), integer()},
          boolean(),
          [String.t()],
          [{integer(), integer(), integer()}]
        ) :: :ok
  def run_kitt(text, duration, speed, {cr, cg, cb}, verbose, frames, colors) do
    text_len = String.length(text)
    iterations = duration * div(1000, speed)

    if verbose do
      Enum.each(0..(iterations - 1), fn frame ->
        IO.puts(build_kitt_frame(text, text_len, frame, {cr, cg, cb}, frames, colors))
      end)
    else
      Enum.each(0..(iterations - 1), fn frame ->
        IO.write(
          "\r\e[K  " <> build_kitt_frame(text, text_len, frame, {cr, cg, cb}, frames, colors)
        )

        Process.sleep(speed)
      end)

      IO.write("\r\e[K")
    end
  end

  @doc """
  Builds a single KITT animation frame as an ANSI string.

  The KITT effect scans a light across the text characters, with
  brightness falling off at the edges.
  """
  @spec build_kitt_frame(
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          {integer(), integer(), integer()},
          [String.t()],
          [{integer(), integer(), integer()}]
        ) :: String.t()
  def build_kitt_frame(text, text_len, frame, {cr, cg, cb}, frames, colors) do
    width = text_len
    cycle = rem(frame, max(width * 2, 1))
    center = if cycle < width, do: cycle, else: width * 2 - cycle - 1

    result =
      text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.map_join(fn {char, i} ->
        dist = abs(i - center)
        fidx = rem(frame, length(frames))
        {fr, fg, fb} = frame_color(fidx, colors, {cr, cg, cb})

        multiplier =
          case dist do
            0 -> 1.0
            1 -> 0.7
            2 -> 0.4
            _ -> 0.5
          end

        "#{Pote.Orchestrator.to_ansi({round(fr * multiplier), round(fg * multiplier), round(fb * multiplier)})}#{char}#{Alaja.ANSI.reset_attributes()}"
      end)

    result <> " "
  end

  @doc """
  Returns the color for a given frame index.

  If `colors` (gradient list) is non-empty and the index is in range,
  returns the color from the gradient list. Otherwise returns `base`.
  """
  @spec frame_color(
          non_neg_integer(),
          [{integer(), integer(), integer()}],
          {integer(), integer(), integer()}
        ) :: {integer(), integer(), integer()}
  def frame_color(idx, colors, base) do
    if colors != [] and idx < length(colors), do: Enum.at(colors, idx), else: base
  end

  # ── Private ──────────────────────────────────────────────────────────

  defp parse_one(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end
end
