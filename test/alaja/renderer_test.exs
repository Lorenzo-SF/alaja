defmodule Alaja.RendererTest do
  use ExUnit.Case, async: true

  alias Alaja.{Frame, Renderer}

  defp render(prev, next), do: IO.iodata_to_binary(Renderer.diff(prev, next))

  defp with_text(w, h, row, text) do
    f = Frame.new(w, h)
    Frame.put_text(f, 1, row, text)
  end

  test "diff with nil prev produces full frame" do
    f = with_text(5, 2, 1, "hello")
    out = render(nil, f)
    assert out =~ "\e[1;1H"
    assert out =~ "hello"
    assert out =~ "\e[0m"
  end

  test "diff of identical frames is empty + reset" do
    f = with_text(5, 2, 1, "hello")
    out = render(f, f)
    assert out == "\e[0m"
  end

  test "diff of changed cell emits CUP + char" do
    f1 = with_text(5, 2, 1, "hello")
    f2 = with_text(5, 2, 1, "hellx")
    out = render(f1, f2)
    assert out =~ "\e[1;5H"
    assert out =~ "x"
    refute out =~ "h"
  end

  test "diff of change in different row" do
    f1 = with_text(5, 2, 2, "hello")
    f2 = with_text(5, 2, 2, "hellx")
    out = render(f1, f2)
    assert out =~ "\e[2;5H"
    assert out =~ "x"
  end

  test "diff of multiple changes in same row" do
    f1 = with_text(5, 1, 1, "hello")
    f2 = with_text(5, 1, 1, "HEYYY")
    out = render(f1, f2)
    # The diff should have a single CUP for the row, then 4 chars
    assert out =~ "\e[1;1H"
    assert out =~ "HEYYY"
    # Only one CUP (the reset ESC[0m doesn't start with "ESC[")
    assert out == "\e[1;1HHEYYY\e[0m"
  end

  test "diff with mismatched sizes does full render" do
    f1 = Frame.new(5, 2)
    f2 = Frame.new(10, 3)
    out = render(f1, f2)
    assert out =~ "\e[1;1H"
    assert out =~ "\e[3;1H"
  end

  test "diff ends with reset" do
    f1 = Frame.new(5, 1)
    f2 = with_text(5, 1, 1, "x")
    out = render(f1, f2)
    assert String.ends_with?(out, "\e[0m")
  end
end
