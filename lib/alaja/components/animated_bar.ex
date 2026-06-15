defmodule Alaja.Components.AnimatedBar do
  @moduledoc """
  Animated bar component with embedded animation in the filled portion.

  Renders a progress bar where the filled portion displays a moving
  animation pattern while the empty portion stays static. The bar
  size is fixed based on value/max ratio, and the animation runs
  indefinitely.

  ## Animation types

  - `:spinner` — spinner characters cycle through the filled portion
  - `:kitt` — a bright scanner spot moves back-and-forth across the filled portion with gradient
  - `:pulse` — the filled portion pulses in intensity
  - `:wave` — a wave-like pattern moves through the filled portion
  - `:rainbow` — colors cycle through the filled portion
  """

  @spinner_frames ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
  @pulse_frames ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂", "▁"]
  @wave_frames ["░", "▒", "▓", "█", "▓", "▒"]

  @doc """
  Renders a single frame of the animated bar.

  ## Options

  - `:animation` — animation type (`:spinner`, `:kitt`, `:pulse`, `:wave`, `:rainbow`; default `:spinner`)
  - `:width` — total bar width in chars (default: 40)
  - `:filled_char` — char for filled portion (default: "▓")
  - `:empty_char` — char for empty portion (default: "░")
  - `:filled_color` — RGB tuple for filled portion color
  - `:empty_color` — RGB tuple for empty portion color
  - `:animation_color` — RGB tuple for the animation highlight
  - `:label` — optional label text before the bar
  - `:show_percent` — show percentage at end (default: true)
  """
  @spec render_frame(number(), number(), non_neg_integer(), keyword()) :: iodata()
  def render_frame(value, max, position, opts \\ []) do
    animation = Keyword.get(opts, :animation, :spinner)
    width = Keyword.get(opts, :width, 40)
    filled_char = Keyword.get(opts, :filled_char, "▓")
    empty_char = Keyword.get(opts, :empty_char, "░")
    show_percent = Keyword.get(opts, :show_percent, true)
    label = Keyword.get(opts, :label)

    ratio = if max > 0, do: min(max(value / max, 0.0), 1.0), else: 0.0
    filled_count = round(ratio * width)
    empty_count = width - filled_count

    filled_part = animate_filled(filled_count, position, animation, filled_char, opts)

    percent_str = if show_percent, do: " #{round(ratio * 100)}%", else: ""
    label_str = if label, do: "#{label} ", else: ""

    [label_str, "[", filled_part, String.duplicate(empty_char, empty_count), "]", percent_str]
  end

  @doc """
  Runs the animated bar in a loop until the process receives
  a shutdown signal, the user presses Ctrl+C, or the maximum
  number of iterations is reached.

  ## Options

  - `:max_iterations` — safety limit to prevent infinite loops (default: 100_000)
  """
  @spec run_infinite(number(), number(), keyword()) :: :ok
  def run_infinite(value, max, opts \\ []) do
    max_iterations = Keyword.get(opts, :max_iterations, 100_000)
    speed = Keyword.get(opts, :speed, 100)
    verbose = Keyword.get(opts, :verbose, false)

    stream = Stream.iterate(0, &(&1 + 1))

    stream
    |> Stream.take(max_iterations)
    |> Enum.each(fn position ->
      frame = render_frame(value, max, position, opts) |> IO.iodata_to_binary()

      if verbose do
        IO.puts(frame)
      else
        IO.write("\r#{frame}")
      end

      Process.sleep(speed)
    end)

    IO.puts("")
  end

  # ---------------------------------------------------------------------------
  # animate_filled/5 clauses — must be grouped together
  # ---------------------------------------------------------------------------

  defp animate_filled(count, position, :spinner, _char, _opts) do
    frame = Enum.at(@spinner_frames, rem(position, length(@spinner_frames)))
    String.duplicate(frame, count)
  end

  defp animate_filled(count, position, :kitt, char, opts) do
    anim_color = Keyword.get(opts, :animation_color)
    filled_color = Keyword.get(opts, :filled_color)
    kitt_width = Keyword.get(opts, :kitt_width, 3)
    {ar, ag, ab} = anim_color || filled_color || {0, 180, 216}

    if count == 0 do
      ""
    else
      total = max(count, 1)

      Enum.map_join(0..(count - 1), "", fn i ->
        dist = abs(i - kitt_position(position, total, kitt_width))
        intensity = max(0.0, 1.0 - dist / kitt_width)
        r = round(ar * intensity)
        g = round(ag * intensity)
        b = round(ab * intensity)
        Pote.Orchestrator.to_ansi({r, g, b}) <> char <> Alaja.ANSI.reset_attributes()
      end)
    end
  end

  defp animate_filled(count, position, :pulse, _char, opts) do
    filled_color = Keyword.get(opts, :filled_color)
    frame_idx = rem(position, length(@pulse_frames))
    pulse_char = Enum.at(@pulse_frames, frame_idx)

    color_ansi(filled_color) <> String.duplicate(pulse_char, count) <> reset()
  end

  defp animate_filled(count, position, :wave, _char, opts) do
    filled_color = Keyword.get(opts, :filled_color)
    wave_len = length(@wave_frames)

    if count == 0 do
      ""
    else
      Enum.map_join(0..(count - 1), "", fn i ->
        wave_idx = rem(i + position, wave_len)
        wave_char = Enum.at(@wave_frames, wave_idx)
        color_ansi(filled_color) <> wave_char <> reset()
      end)
    end
  end

  defp animate_filled(count, position, :rainbow, char, _opts) do
    rainbow = [
      {255, 0, 0},
      {255, 127, 0},
      {255, 255, 0},
      {0, 255, 0},
      {0, 0, 255},
      {75, 0, 130},
      {143, 0, 255}
    ]

    if count == 0 do
      ""
    else
      Enum.map_join(0..(count - 1), "", fn i ->
        idx = rem(i + position, length(rainbow))
        {r, g, b} = Enum.at(rainbow, idx)
        Pote.Orchestrator.to_ansi({r, g, b}) <> char <> Alaja.ANSI.reset_attributes()
      end)
    end
  end

  defp animate_filled(count, position, _type, char, opts) do
    animate_filled(count, position, :spinner, char, opts)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp kitt_position(frame, count, kitt_width) do
    range = count + max(kitt_width, 1) - 1
    cycle = max(range, 1) * 2
    pos = rem(frame, cycle)
    if pos < range, do: pos, else: range * 2 - pos
  end

  defp color_ansi(nil), do: ""
  defp color_ansi({r, g, b}), do: Pote.Orchestrator.to_ansi({r, g, b})

  defp reset, do: Alaja.ANSI.reset_attributes()
end
