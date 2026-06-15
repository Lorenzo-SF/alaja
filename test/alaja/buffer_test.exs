defmodule Alaja.BufferTest do
  use ExUnit.Case
  alias Alaja.{Buffer, Cell}

  describe "new/2" do
    test "creates a buffer with given dimensions" do
      buffer = Buffer.new(80, 24)
      assert buffer.width == 80
      assert buffer.height == 24
      assert tuple_size(buffer.cells) == 80 * 24
    end
  end

  describe "put/6" do
    test "updates a specific cell with char, fg, and bg if valid" do
      buffer = Buffer.new(10, 10)
      buf = Buffer.put(buffer, 2, 2, "X", {255, 0, 0}, {0, 0, 0})

      cell = Buffer.get(buf, 2, 2)
      assert cell.char == "X"
      assert cell.fg == {255, 0, 0}
      assert cell.bg == {0, 0, 0}
    end

    test "ignores put when out of bounds" do
      buffer = Buffer.new(10, 10)
      buf = Buffer.put(buffer, 12, 12, "X", {255, 0, 0}, {0, 0, 0})
      # Buffer is pre-allocated so size stays same
      assert tuple_size(buf.cells) == 100
    end
  end

  describe "get/3" do
    test "returns the stored cell if valid" do
      buffer = Buffer.new(10, 10)
      cell = Cell.new("A", {255, 0, 0})
      buf = Buffer.update_cell(buffer, 5, 5, cell)

      retrieved = Buffer.get(buf, 5, 5)
      assert retrieved.char == "A"
      assert retrieved.fg == {255, 0, 0}
    end

    test "returns default cell for unoccupied valid bounds" do
      buffer = Buffer.new(10, 10)
      empty = Buffer.get(buffer, 0, 0)
      assert empty.char == " "
    end

    test "returns default cell for out of bounds" do
      buffer = Buffer.new(10, 10)
      oob = Buffer.get(buffer, 99, 99)
      assert oob.char == " "
    end
  end

  describe "update_cell/4 (Cell struct signature)" do
    test "adds a cell struct to the buffer" do
      buffer = Buffer.new(10, 10)
      cell = Cell.new("A", {255, 0, 0})
      buf = Buffer.update_cell(buffer, 5, 5, cell)

      retrieved = Buffer.get(buf, 5, 5)
      assert retrieved.char == "A"
      assert retrieved.fg == {255, 0, 0}
    end

    test "ignores out of bounds update_cell/4" do
      buffer = Buffer.new(10, 10)
      cell = Cell.new("A", {255, 0, 0})
      buf = Buffer.update_cell(buffer, -1, 5, cell)
      # Buffer is pre-allocated so tuple_size stays same
      assert tuple_size(buf.cells) == 100
    end
  end

  describe "update_cell/6 (char, fg, bg signature)" do
    test "adds a cell by args to the buffer" do
      buffer = Buffer.new(10, 10)
      buf = Buffer.update_cell(buffer, 5, 5, "Z", {0, 255, 0}, nil)

      retrieved = Buffer.get(buf, 5, 5)
      assert retrieved.char == "Z"
      assert retrieved.fg == {0, 255, 0}
    end

    test "ignores out of bounds update_cell/6" do
      buffer = Buffer.new(10, 10)
      buf = Buffer.update_cell(buffer, 20, 5, "Z", nil, nil)
      # Buffer is pre-allocated so tuple_size stays same
      assert tuple_size(buf.cells) == 100
    end
  end

  describe "valid_coord?/3" do
    test "returns true for inside bounds" do
      buffer = Buffer.new(10, 10)
      assert Buffer.valid_coord?(buffer, 0, 0) == true
      assert Buffer.valid_coord?(buffer, 9, 9) == true
    end

    test "returns false for outside bounds" do
      buffer = Buffer.new(10, 10)
      assert Buffer.valid_coord?(buffer, -1, 5) == false
      assert Buffer.valid_coord?(buffer, 5, -1) == false
      assert Buffer.valid_coord?(buffer, 10, 5) == false
      assert Buffer.valid_coord?(buffer, 5, 10) == false
    end
  end

  describe "clear/1" do
    test "empties all cells in the buffer" do
      buffer = Buffer.new(10, 10) |> Buffer.put(5, 5, "X", {255, 0, 0})
      assert tuple_size(buffer.cells) == 100

      cleared = Buffer.clear(buffer)
      assert tuple_size(cleared.cells) == 100
      assert Buffer.get(cleared, 5, 5).char == " "
    end
  end

  describe "fill/8" do
    test "fills a rectangular region" do
      buffer = Buffer.new(10, 10)
      filled = Buffer.fill(buffer, 1, 1, 3, 3, "B", {0, 0, 255}, {100, 100, 100})

      # Buffer stays 10x10 = 100 cells
      assert tuple_size(filled.cells) == 100

      top_left = Buffer.get(filled, 1, 1)
      assert top_left.char == "B"
      assert top_left.fg == {0, 0, 255}

      outside = Buffer.get(filled, 0, 0)
      assert outside.char == " "
    end
  end

  describe "merge/2" do
    test "buffer2 cells override buffer1 cells" do
      buf1 = Buffer.new(3, 2)
      buf1 = Buffer.put(buf1, 0, 0, "A", {255, 0, 0})
      buf1 = Buffer.put(buf1, 1, 0, "B", {0, 255, 0})
      buf1 = Buffer.put(buf1, 2, 0, "C", {0, 0, 255})

      buf2 = Buffer.new(3, 2)
      buf2 = Buffer.put(buf2, 0, 0, "X", {255, 255, 0})
      buf2 = Buffer.put(buf2, 1, 0, "Y", {0, 255, 255})

      merged = Buffer.merge(buf1, buf2)

      # buf2 cells that are non-empty override
      assert Buffer.get(merged, 0, 0).char == "X"
      assert Buffer.get(merged, 1, 0).char == "Y"
      # buf1 cells not in buf2 are preserved
      assert Buffer.get(merged, 2, 0).char == "C"
      # row 1 is empty in both
      assert Buffer.get(merged, 0, 1).char == " "
    end

    test "empty cells in buffer2 preserve buffer1 cells" do
      buf1 = Buffer.new(2, 1)
      buf1 = Buffer.put(buf1, 0, 0, "A", {255, 0, 0})

      buf2 = Buffer.new(2, 1)
      # buf2 has no put calls, all empty

      merged = Buffer.merge(buf1, buf2)
      assert Buffer.get(merged, 0, 0).char == "A"
      assert Buffer.get(merged, 1, 0).char == " "
    end
  end

  describe "write/4 (char-only alias)" do
    test "writes a character without colors" do
      buffer = Buffer.new(5, 5)
      buf = Buffer.write(buffer, 2, 2, "W")
      assert Buffer.get(buf, 2, 2).char == "W"
    end
  end

  describe "write/6 (char + colors alias)" do
    test "writes a character with foreground and background" do
      buffer = Buffer.new(5, 5)
      buf = Buffer.write(buffer, 3, 3, "C", {128, 0, 128}, {50, 50, 50})
      cell = Buffer.get(buf, 3, 3)
      assert cell.char == "C"
      assert cell.fg == {128, 0, 128}
      assert cell.bg == {50, 50, 50}
    end
  end

  describe "write/4 (keyword opts alias)" do
    test "writes a character with keyword list options" do
      buffer = Buffer.new(5, 5)
      buf = Buffer.write(buffer, 1, 1, "K", fg: {0, 128, 0}, bg: {0, 0, 128})
      cell = Buffer.get(buf, 1, 1)
      assert cell.char == "K"
      assert cell.fg == {0, 128, 0}
      assert cell.bg == {0, 0, 128}
    end
  end
end
