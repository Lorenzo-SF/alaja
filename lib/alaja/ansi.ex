defmodule Alaja.ANSI do
  @moduledoc """
  Pure ANSI escape code generators.

  Returns strings containing ANSI escape sequences for cursor control,
  screen manipulation, true-colour foreground/background, mouse event
  handling, and alternate screen buffers.
  """

  @doc "Hides the terminal cursor."
  @spec hide_cursor() :: String.t()
  def hide_cursor, do: "\e[?25l"

  @doc "Shows the terminal cursor."
  @spec show_cursor() :: String.t()
  def show_cursor, do: "\e[?25h"

  @doc "Clears the entire screen (alias for `clear_screen/0`)."
  @spec clear() :: String.t()
  def clear, do: clear_screen()

  @doc "Clears the entire screen."
  @spec clear_screen() :: String.t()
  def clear_screen, do: "\e[2J"

  @doc "Clears the current line."
  @spec clear_line() :: String.t()
  def clear_line, do: "\e[K"

  @doc "Clears from cursor to the end of the screen."
  @spec clear_line_down() :: String.t()
  def clear_line_down, do: "\e[J"

  @doc "Moves cursor to position (alias for `move_to/2`)."
  @spec move(non_neg_integer(), non_neg_integer()) :: String.t()
  def move(x, y), do: move_to(x, y)

  @doc """
  Moves cursor to position (1-indexed).

  `col` is the column (x), `row` is the row (y).
  """
  @spec move_to(pos_integer(), pos_integer()) :: String.t()
  def move_to(col, row), do: "\e[#{row};#{col}H"

  @doc "Moves cursor to home position (1,1)."
  @spec cursor_home() :: String.t()
  def cursor_home, do: "\e[H"

  @doc "Saves cursor position."
  @spec save_cursor() :: String.t()
  def save_cursor, do: "\e7"

  @doc "Restores cursor position."
  @spec restore_cursor() :: String.t()
  def restore_cursor, do: "\e8"

  @doc "Resets all text attributes."
  @spec reset_attributes() :: String.t()
  def reset_attributes, do: "\e[0m"

  @doc "Alias for `reset_attributes/0`."
  @spec reset() :: String.t()
  def reset, do: reset_attributes()

  @doc "Turns bold text on (alias for `bold_on/0`)."
  @spec bold() :: String.t()
  def bold, do: bold_on()

  @doc "Turns bold text on."
  @spec bold_on() :: String.t()
  def bold_on, do: "\e[1m"

  @doc "Turns italic text on (alias for `italic_on/0`)."
  @spec italic() :: String.t()
  def italic, do: italic_on()

  @doc "Turns italic text on."
  @spec italic_on() :: String.t()
  def italic_on, do: "\e[3m"

  @doc "Turns underline on."
  @spec underline_on() :: String.t()
  def underline_on, do: "\e[4m"

  @doc "Turns faint/dim text on (alias for `faint_on/0`)."
  @spec dim() :: String.t()
  def dim, do: faint_on()

  @doc "Turns faint/dim text on."
  @spec faint_on() :: String.t()
  def faint_on, do: "\e[2m"

  @doc "Enables mouse tracking (SGR extended mode)."
  @spec mouse_on() :: String.t()
  def mouse_on, do: "\e[?1000h\e[?1006h"

  @doc "Disables mouse tracking."
  @spec mouse_off() :: String.t()
  def mouse_off, do: "\e[?1000l\e[?1006l"

  @doc "Enables SGR mouse mode."
  @spec mouse_sgr_on() :: String.t()
  def mouse_sgr_on, do: "\e[?1006h"

  @doc "Disables SGR mouse mode."
  @spec mouse_sgr_off() :: String.t()
  def mouse_sgr_off, do: "\e[?1006l"

  @doc "Switches to alternate screen buffer."
  @spec alt_screen_on() :: String.t()
  def alt_screen_on, do: "\e[?1049h"

  @doc "Switches back to normal screen buffer."
  @spec alt_screen_off() :: String.t()
  def alt_screen_off, do: "\e[?1049l"

  @doc """
  Sets 24-bit true-color foreground.

  Returns ANSI escape: `\\e[38;2;R;G;Bm`
  """
  @spec fg(0..255, 0..255, 0..255) :: String.t()
  def fg(r, g, b), do: "\e[38;2;#{r};#{g};#{b}m"

  @doc """
  Sets 24-bit true-color background.

  Returns ANSI escape: `\\e[48;2;R;G;Bm`
  """
  @spec bg(0..255, 0..255, 0..255) :: String.t()
  def bg(r, g, b), do: "\e[48;2;#{r};#{g};#{b}m"
end
