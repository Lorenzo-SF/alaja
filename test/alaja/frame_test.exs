defmodule Alaja.FrameTest do
  use ExUnit.Case, async: true

  alias Alaja.{Buffer, Frame}

  test "new/2 creates an empty frame" do
    f = Frame.new(80, 24)
    assert Frame.width(f) == 80
    assert Frame.height(f) == 24
    assert Frame.row_text(f, 1) == ""
    assert Frame.row_text(f, 24) == ""
  end

  test "put_text/4 writes text at (x, y) padded with spaces" do
    f =
      Frame.new(10, 3)
      |> Frame.put_text(1, 1, "hello")

    assert Frame.row_text(f, 1) == "hello"
  end

  test "put_text/4 truncates past frame width" do
    f =
      Frame.new(3, 1)
      |> Frame.put_text(1, 1, "hello world")

    assert Frame.row_text(f, 1) == "hel"
  end

  test "put/4 writes single char" do
    f =
      Frame.new(5, 1)
      |> Frame.put(3, 1, "x")

    # row_text trims trailing spaces
    assert Frame.row_text(f, 1) == "  x"
  end

  test "row_text/2 returns trimmed string" do
    f =
      Frame.new(10, 1)
      |> Frame.put_text(1, 1, "hi")

    assert Frame.row_text(f, 1) == "hi"
  end

  test "cells/1 returns %{coords => char}" do
    f =
      Frame.new(3, 2)
      |> Frame.put_text(1, 1, "abc")
      |> Frame.put_text(1, 2, "xyz")

    cells = Frame.cells(f)
    assert cells[{1, 1}] == "a"
    assert cells[{3, 1}] == "c"
    assert cells[{2, 2}] == "y"
  end

  test "clear/1 resets the frame" do
    f =
      Frame.new(3, 1)
      |> Frame.put_text(1, 1, "abc")
      |> Frame.clear()

    assert Frame.row_text(f, 1) == ""
  end

  test "buffer/1 returns the underlying buffer" do
    f = Frame.new(4, 2)
    buf = Frame.buffer(f)
    assert %Buffer{width: 4, height: 2} = buf
  end
end
