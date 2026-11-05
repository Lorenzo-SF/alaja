defmodule Alaja.PrinterTerminalResetTest do
  @moduledoc """
  The terminal must never be left with a colour or effect open.

  Output that ends on a set-code hands that state to whatever runs next
  on the same terminal, so running several commands in a row made each
  one inherit the previous one's colour until it happened to set its
  own — and leaked into the shell prompt in between.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Alaja.Printer

  describe "attributes_left_open?/1" do
    test "false for plain text" do
      refute Printer.attributes_left_open?("hello")
    end

    test "false for an empty payload" do
      refute Printer.attributes_left_open?("")
    end

    test "true when the last SGR sets a colour" do
      assert Printer.attributes_left_open?("\e[38;2;166;227;161mx")
    end

    test "true when the last SGR turns bold on" do
      assert Printer.attributes_left_open?("\e[1mx")
    end

    test "false when the payload already resets" do
      refute Printer.attributes_left_open?("\e[38;2;166;227;161mx\e[0m")
    end

    test "the last SGR decides, even after an earlier reset" do
      # The reset in the middle clears the 31, but \e[1m reopens bold, so
      # the payload still ends with something open.
      assert Printer.attributes_left_open?("a\e[31mb\e[0mc\e[1md")
    end

    test "true when a selective off leaves another attribute open" do
      # \e[22m is bold-off; the 31 from before is still red.
      assert Printer.attributes_left_open?("\e[1;31mx\e[22m")
    end

    test "true after a selective colour-off" do
      # \e[39m restores the default fg, but bold from earlier survives.
      assert Printer.attributes_left_open?("\e[1m\e[31mx\e[39m")
    end

    test "ignores a bare ESC[m, which is a full reset" do
      refute Printer.attributes_left_open?("\e[31mx\e[m")
    end

    test "true for a background colour left open" do
      assert Printer.attributes_left_open?("\e[48;2;1;2;3mx")
    end

    test "does not treat a non-SGR escape as an open attribute" do
      # A cursor move is an escape but not a colour change.
      refute Printer.attributes_left_open?("\e[2Jhello")
    end

    test "accepts iodata as well as a binary" do
      assert Printer.attributes_left_open?(["\e[31m", "x"])
    end
  end

  describe "append_terminal_reset/2" do
    test "closes an open attribute" do
      assert IO.iodata_to_binary(Printer.append_terminal_reset("\e[31mx", [])) == "\e[31mx\e[0m"
    end

    test "leaves an already-balanced payload byte-identical" do
      # Snapshots and the test suite compare rendered output exactly, so
      # a payload that resets itself must not gain four bytes.
      payload = "\e[31mx\e[0m"
      assert IO.iodata_to_binary(Printer.append_terminal_reset(payload, [])) == payload
    end

    test "leaves plain text byte-identical" do
      assert IO.iodata_to_binary(Printer.append_terminal_reset("hello", [])) == "hello"
    end

    test "honours reset: false for callers that emit their own terminator" do
      payload = "\e[31mx"
      assert IO.iodata_to_binary(Printer.append_terminal_reset(payload, reset: false)) == payload
    end
  end

  describe "rendered output" do
    test "a coloured message ends with a reset" do
      output = capture_io(fn -> Alaja.print_info("done") end)

      assert output =~ "done"

      assert String.trim_trailing(output) =~ ~r/\e\[0m\z/,
             "output left the terminal in a coloured state: #{inspect(output)}"
    end

    test "every message type closes its own attributes" do
      for fun <- [
            &Alaja.print_success/1,
            &Alaja.print_error/1,
            &Alaja.print_info/1,
            &Alaja.print_warning/1
          ] do
        output = capture_io(fn -> fun.("msg") end)

        assert String.trim_trailing(output) =~ ~r/\e\[0m\z/,
               "#{inspect(fun)} left the terminal coloured: #{inspect(output)}"
      end
    end

    test "consecutive messages are each self-contained" do
      first = capture_io(fn -> Alaja.print_error("uno") end)
      second = capture_io(fn -> Alaja.print_success("dos") end)

      # The second must not depend on the first having reset anything.
      assert String.trim_trailing(first) =~ ~r/\e\[0m\z/
      assert String.trim_trailing(second) =~ ~r/\e\[0m\z/
    end

    test "raw output is passed through untouched" do
      assert capture_io(fn -> Alaja.print_raw("plain") end) == "plain"
    end
  end
end
