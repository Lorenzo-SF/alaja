defmodule Alaja.ANSITest do
  use ExUnit.Case

  alias Alaja.ANSI

  describe "cursor control" do
    test "hide_cursor/0 returns string" do
      assert ANSI.hide_cursor() == "\e[?25l"
    end

    test "show_cursor/0 returns string" do
      assert ANSI.show_cursor() == "\e[?25h"
    end

    test "clear_screen/0 returns string" do
      assert ANSI.clear_screen() == "\e[2J"
    end

    test "clear_line/0 returns string" do
      assert ANSI.clear_line() == "\e[K"
    end

    test "move_to/2 positions cursor" do
      assert ANSI.move_to(10, 5) == "\e[5;10H"
    end

    test "cursor_home/0 returns string" do
      assert ANSI.cursor_home() == "\e[H"
    end
  end

  describe "text attributes" do
    test "reset_attributes/0 returns reset code" do
      assert ANSI.reset_attributes() == "\e[0m"
    end

    test "reset/0 returns reset code" do
      assert ANSI.reset() == "\e[0m"
    end

    test "bold_on/0 returns bold code" do
      assert ANSI.bold_on() == "\e[1m"
    end

    test "italic_on/0 returns italic code" do
      assert ANSI.italic_on() == "\e[3m"
    end

    test "underline_on/0 returns underline code" do
      assert ANSI.underline_on() == "\e[4m"
    end
  end

  describe "true color" do
    test "fg/3 returns foreground escape" do
      assert ANSI.fg(255, 0, 0) == "\e[38;2;255;0;0m"
    end

    test "bg/3 returns background escape" do
      assert ANSI.bg(0, 255, 0) == "\e[48;2;0;255;0m"
    end
  end

  describe "screen modes" do
    test "alt_screen_on/0 returns alternate screen code" do
      assert ANSI.alt_screen_on() == "\e[?1049h"
    end

    test "alt_screen_off/0 returns alternate screen code" do
      assert ANSI.alt_screen_off() == "\e[?1049l"
    end
  end

  describe "mouse tracking" do
    test "mouse_on/0 enables mouse" do
      assert ANSI.mouse_on() == "\e[?1000h\e[?1006h"
    end

    test "mouse_off/0 disables mouse" do
      assert ANSI.mouse_off() == "\e[?1000l\e[?1006l"
    end
  end

  describe "cursor save/restore" do
    test "save_cursor/0 returns save code" do
      assert ANSI.save_cursor() == "\e7"
    end

    test "restore_cursor/0 returns restore code" do
      assert ANSI.restore_cursor() == "\e8"
    end
  end
end
