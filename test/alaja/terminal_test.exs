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
end
