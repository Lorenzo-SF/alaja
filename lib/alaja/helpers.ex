defmodule Alaja.Helpers do
  @moduledoc """
  High-level drawing helpers for TUI applications.

  Provides functions for common UI patterns like:
  - Braille sparklines
  - Progress bars with color gradients
  - Box drawing (single and double border)
  - Color interpolation utilities

  Note: Basic ANSI escape functions have been moved to `Alaja.ANSI`.
  This module now focuses on high-level helpers only.
  """

  alias Alaja.ANSI, as: ANSI

  @doc """
  Safely converts a string to an existing atom.

  Wraps `String.to_existing_atom/1` in a try/rescue to prevent
  atom table exhaustion from untrusted input.

  Returns `{:ok, atom}` on success, `{:error, message}` if the atom does not exist.
  """
  @spec safe_string_to_atom(String.t()) :: {:ok, atom()} | {:error, String.t()}
  def safe_string_to_atom(s) when is_binary(s) do
    {:ok, String.to_existing_atom(s)}
  rescue
    ArgumentError ->
      {:error, "atom '#{s}' does not exist"}
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # Braille Sparklines
  # ═══════════════════════════════════════════════════════════════════════════════

  @braille_chars [" ", "⣀", "⣤", "⣶", "⣿", "⡿", "⠿"]

  @doc """
  Generate a braille sparkline from a list of values (0-100).

  ## Parameters
    - values: List of numbers (0-100)
    - width: Maximum number of braille characters to display

  ## Returns
  A string of braille characters representing the data.

  ## Example
      iex> Helpers.braille_spark([10, 50, 90, 30], 4)
      "⣤ ⣿ ⣤ ⣀"
  """
  def braille_spark(values, width) do
    values
    |> Enum.take(width)
    |> Enum.map_join(" ", fn v ->
      idx = min(6, max(0, round(v / 100 * 6)))
      Enum.at(@braille_chars, idx)
    end)
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # Progress Bars
  # ═══════════════════════════════════════════════════════════════════════════════

  @doc """
  Generate a progress bar with color gradient.

  ## Parameters
    - pct: Percentage (0-100)
    - width: Width of the bar in characters
    - color_start: Starting color as {r, g, b}
    - color_end: Ending color as {r, g, b}

  ## Returns
  A string containing the progress bar with percentage display.

  ## Example
      iex> Helpers.progress_bar(75, 20, {80, 140, 255}, {200, 100, 255})
      "███████████████████░░░ 75%"
  """
  def progress_bar(pct, width, color_start, color_end) do
    clamped_pct = min(100, max(0, pct))
    filled = round(width * clamped_pct / 100)

    bar =
      for i <- 0..(width - 1), into: "" do
        t = if width > 1, do: i / (width - 1), else: 0.0
        {r, g, b} = lerp(color_start, color_end, t)

        if i < filled do
          "#{ANSI.fg(r, g, b)}█"
        else
          "#{ANSI.dim()}░#{ANSI.reset()}"
        end
      end

    "#{bar}#{ANSI.reset()} #{ANSI.bold()}#{round(clamped_pct)}%#{ANSI.reset()}"
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # Box Drawing
  # ═══════════════════════════════════════════════════════════════════════════════

  @doc """
  Draw a box with single-line border.

  ## Parameters
    - x, y: Starting position (1-indexed)
    - w, h: Width and height
    - title: Optional title (default: "")
    - color: RGB color as {r, g, b} (default: {100, 140, 200})

  ## Returns
  A list of {x, y, text} tuples for rendering.

  ## Example
      iex> Helpers.box(1, 1, 40, 10, "My Box", {100, 140, 200})
      [{1, 1, "╭──────────────────────────────────────╮"}, ...]
  """
  def box(x, y, w, h, title \\ "", color \\ {100, 140, 200}) do
    {r, g, b} = color
    c = ANSI.fg(r, g, b)

    top = {x, y, "#{c}╭#{String.duplicate("─", w - 2)}╮#{ANSI.reset()}"}
    bottom = {x, y + h - 1, "#{c}╰#{String.duplicate("─", w - 2)}╯#{ANSI.reset()}"}

    sides =
      for row <- 1..(h - 2) do
        {x, y + row, "#{c}│#{String.duplicate(" ", w - 2)}│#{ANSI.reset()}"}
      end

    title_line =
      if title != "" do
        title_x = x + div(w - String.length(" #{title} "), 2)
        [{title_x, y, "#{c}#{ANSI.bold()} #{title} #{ANSI.reset()}"}]
      else
        []
      end

    [top, bottom] ++ sides ++ title_line
  end

  @doc """
  Draw a box with double-line border.

  ## Parameters
    - x, y: Starting position (1-indexed)
    - w, h: Width and height
    - title: Optional title (default: "")
    - color: RGB color as {r, g, b} (default: {180, 130, 80})

  ## Returns
  A list of {x, y, text} tuples for rendering.

  ## Example
      iex> Helpers.double_box(1, 1, 40, 10, "Workers", {180, 130, 80})
      [{1, 1, "╔══════════════════════════════════════╗"}, ...]
  """
  def double_box(x, y, w, h, title \\ "", color \\ {180, 130, 80}) do
    {r, g, b} = color
    c = ANSI.fg(r, g, b)

    top = {x, y, "#{c}╔#{String.duplicate("═", w - 2)}╗#{ANSI.reset()}"}
    bottom = {x, y + h - 1, "#{c}╚#{String.duplicate("═", w - 2)}╝#{ANSI.reset()}"}

    sides =
      for row <- 1..(h - 2) do
        {x, y + row, "#{c}║#{String.duplicate(" ", w - 2)}║#{ANSI.reset()}"}
      end

    title_line =
      if title != "" do
        title_x = x + div(w - String.length(" #{title} "), 2)
        [{title_x, y, "#{c}#{ANSI.bold()} #{title} #{ANSI.reset()}"}]
      else
        []
      end

    [top, bottom] ++ sides ++ title_line
  end

  # ═══════════════════════════════════════════════════════════════════════════════
  # Color Utilities
  # ═══════════════════════════════════════════════════════════════════════════════

  @doc """
  Linear interpolation between two RGB colors.

  ## Parameters
    - c1: Starting color {r, g, b}
    - c2: Ending color {r, g, b}
    - t: Interpolation factor (0.0 to 1.0)

  ## Returns
  Interpolated color as {r, g, b}.

  ## Example
      iex> Helpers.lerp({0, 0, 0}, {255, 255, 255}, 0.5)
      {127, 127, 127}
  """
  def lerp({r1, g1, b1}, {r2, g2, b2}, t) do
    {
      round(r1 + (r2 - r1) * t),
      round(g1 + (g2 - g1) * t),
      round(b1 + (b2 - b1) * t)
    }
  end
end
