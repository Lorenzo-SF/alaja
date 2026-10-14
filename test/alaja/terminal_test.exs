defmodule Alaja.TerminalTest do
  use ExUnit.Case

  alias Alaja.Terminal

  describe "size/0" do
    test "returns a tuple of two positive integers" do
      {cols, rows} = Terminal.size()
      assert is_integer(cols) and cols > 0
      assert is_integer(rows) and rows > 0
    end
  end

  describe "width/0" do
    test "returns a positive integer" do
      assert is_integer(Terminal.width()) and Terminal.width() > 0
    end
  end

  describe "height/0" do
    test "returns a positive integer" do
      assert is_integer(Terminal.height()) and Terminal.height() > 0
    end
  end

  describe "tty?/0" do
    test "returns a boolean" do
      assert is_boolean(Terminal.tty?())
    end

    test "is stable across calls (the value is cached)" do
      assert Terminal.tty?() == Terminal.tty?()
    end

    test "agrees with the type of the process's own fd 1" do
      # The probe is `File.stat("/dev/fd/1")`, which the kernel resolves
      # against *this* process. Under ExUnit stdout is a capture pipe, so
      # the honest expectation here is "not a terminal" — asserted by
      # comparing against the same stat rather than a hardcoded false, so
      # the test still says something true when run from a real terminal.
      assert Terminal.tty?() ==
               match?({:ok, %File.Stat{type: :device}}, File.stat("/dev/fd/1"))
    end

    test "is false under a redirected stdout" do
      # ExUnit captures stdout, which is the whole point: a CLI that emits
      # ANSI into a pipe is the bug this module exists to prevent.
      refute Terminal.tty?()
    end
  end
end
