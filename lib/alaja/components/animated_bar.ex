defmodule Alaja.Components.AnimatedBar do
  alias Alaja.Buffer

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
  Renders a single frame of the animated bar as an `Alaja.Buffer.t/0`.

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
  @spec render_frame(number(), number(), non_neg_integer(), keyword()) :: Buffer.t()
  def render_frame(value, max, position, opts \\ []) do
    animation = Keyword.get(opts, :animation, :spinner)
    width = Keyword.get(opts, :width, 40)
    filled_char = Keyword.get(opts, :filled_char, "▓")
    empty_char = Keyword.get(opts, :empty_char, "░")
    show_percent = Keyword.get(opts, :show_percent, true)
    label = Keyword.get(opts, :label)
    filled_color = Keyword.get(opts, :filled_color)
    _empty_color = Keyword.get(opts, :empty_color)

    ratio = if max > 0, do: min(max(value / max, 0.0), 1.0), else: 0.0
    filled_count = round(ratio * width)
    empty_count = width - filled_count

    filled_part =
      animate_filled(filled_count, position, animation, filled_char, opts)

    percent_str = if show_percent, do: " #{round(ratio * 100)}%", else: ""
    label_str = if label, do: "#{label} ", else: ""

    # Buffer plan: one row, with the following pieces in order
    #   label | "[" | filled_part | empty_portion | "]" | percent_str
    # Empty portion is the same as the original animate_filled fallback path
    # for non-spacer animations; for compatibility we mirror the previous
    # empty_char behavior.
    empty_portion = String.duplicate(empty_char, empty_count)

    buffer =
      Buffer.new(
        String.length(label_str) + 1 + width + 1 + String.length(percent_str),
        1
      )

    # Write each piece as cells. animate_filled/5 returns [{char, fg}]
    # tuples — no raw ANSI escapes — so we can Buffer.put/6 per cell.
    buffer = write_piece(buffer, 0, 0, label_str)
    offset = String.length(label_str)
    buffer = write_piece(buffer, offset, 0, "[")
    offset = offset + 1
    {buffer, offset} = write_cells(buffer, offset, 0, filled_part)
    {buffer, offset} = write_piece_with_offset(buffer, offset, 0, empty_portion)
    buffer = write_piece(buffer, offset, 0, "]")
    offset = offset + 1
    write_piece(buffer, offset, 0, percent_str)
  end

  # ---------------------------------------------------------------------------
  # Internal: write a plain string into a Buffer
  # ---------------------------------------------------------------------------

  defp write_piece(buffer, x, y, text, _fg \\ nil) do
    Alaja.Buffer.write_string(buffer, x, y, text)
  end

  defp write_piece_with_offset(buffer, x, y, text) do
    buf = Alaja.Buffer.write_string(buffer, x, y, text)
    {buf, x + String.length(text)}
  end

  # Write a list of {char, fg} tuples into the buffer starting at (x, y).
  # Each tuple becomes one Buffer cell with the given fg color (or nil
  # for uncolored). Returns {buffer, next_x}.
  defp write_cells(buffer, x, y, cells) do
    Enum.reduce(cells, {buffer, x}, fn {char, fg}, {buf, cx} ->
      if cx < buf.width do
        {Buffer.put(buf, cx, y, char, fg), cx + 1}
      else
        {buf, cx + 1}
      end
    end)
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
      frame =
        render_frame(value, max, position, opts)
        |> Buffer.to_iodata()
        |> IO.iodata_to_binary()

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
  #
  # Each clause returns a list of {char, fg} tuples — no raw ANSI escapes.
  # The cells are written into the Buffer with proper fg colours, so the
  # output survives Buffer.to_iodata/1's RLE pass without truncation.

  defp animate_filled(count, position, :spinner, _char, opts) do
    filled_color = Keyword.get(opts, :filled_color)
    frame = Enum.at(@spinner_frames, rem(position, length(@spinner_frames)))
    List.duplicate({frame, filled_color}, count)
  end

  defp animate_filled(count, position, :kitt, char, opts) do
    anim_color = Keyword.get(opts, :animation_color)
    filled_color = Keyword.get(opts, :filled_color)
    kitt_width = Keyword.get(opts, :kitt_width, 3)
    {ar, ag, ab} = anim_color || filled_color || {0, 180, 216}

    if count == 0 do
      []
    else
      total = max(count, 1)

      for i <- 0..(count - 1) do
        dist = abs(i - kitt_position(position, total, kitt_width))
        intensity = max(0.0, 1.0 - dist / kitt_width)
        r = round(ar * intensity)
        g = round(ag * intensity)
        b = round(ab * intensity)
        {char, {r, g, b}}
      end
    end
  end

  defp animate_filled(count, position, :pulse, _char, opts) do
    filled_color = Keyword.get(opts, :filled_color)
    frame_idx = rem(position, length(@pulse_frames))
    pulse_char = Enum.at(@pulse_frames, frame_idx)

    List.duplicate({pulse_char, filled_color}, count)
  end

  defp animate_filled(count, position, :wave, _char, opts) do
    filled_color = Keyword.get(opts, :filled_color)
    wave_len = length(@wave_frames)

    if count == 0 do
      []
    else
      for i <- 0..(count - 1) do
        wave_idx = rem(i + position, wave_len)
        wave_char = Enum.at(@wave_frames, wave_idx)
        {wave_char, filled_color}
      end
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
      []
    else
      for i <- 0..(count - 1) do
        idx = rem(i + position, length(rainbow))
        {char, Enum.at(rainbow, idx)}
      end
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
end
