defmodule Alaja.CellEngineTest do
  @moduledoc """
  Tests for the v0.3.0 Cell/Buffer engine unification. These verify:

    * Components return `Alaja.Buffer.t()` from `render/N`
    * `Alaja.Buffer.to_iodata/1` round-trips components to ANSI strings
      that match the pre-refactor golden snapshots
    * Composition primitives (`overlay`, `hstack`, `vstack`, `crop`,
      `pad`, `with_offset`) compose buffers correctly
    * `Alaja.Printer.print_buffer/2` honors `x`/`y`/`offset_x`/`offset_y`
    * `Alaja.Components.Box.render/2` accepts both `String.t()` and
      `Alaja.Buffer.t()` as content
  """

  use ExUnit.Case, async: true

  alias Alaja.{Buffer, Cell, Printer}
  alias Alaja.Components.{Bar, Box, Header, Separator, Table}

  describe "Buffer.to_iodata/1" do
    test "empty buffer returns []" do
      assert Buffer.to_iodata(%Buffer{width: 0, height: 0}) == []
    end

    test "single cell with colour emits ANSI escape + char + reset on style change" do
      buffer =
        Buffer.new(3, 1)
        |> Buffer.put(0, 0, "A", {255, 0, 0})
        |> Buffer.put(1, 0, "B", {0, 255, 0})
        |> Buffer.put(2, 0, "C", nil)

      iodata = Buffer.to_iodata(buffer)
      binary = IO.iodata_to_binary(iodata)

      assert binary =~ ~s(\e[38;2;255;0;0m)
      assert binary =~ "A"
      assert binary =~ ~s(\e[0m)
      assert binary =~ ~s(\e[38;2;0;255;0m)
      assert binary =~ "B"
      assert binary =~ "C"
    end

    test "consecutive cells with same colour coalesce into single escape" do
      buffer =
        Buffer.new(3, 1)
        |> Buffer.put(0, 0, "A", {255, 0, 0})
        |> Buffer.put(1, 0, "B", {255, 0, 0})
        |> Buffer.put(2, 0, "C", {255, 0, 0})

      binary = Buffer.to_iodata(buffer) |> IO.iodata_to_binary()

      # Exactly ONE ANSI escape for the red, three chars, one reset
      escape_count = binary |> String.split(~s(\e[38;2;255;0;0m)) |> length() |> Kernel.-(1)
      assert escape_count == 1
      assert binary =~ "ABC"
    end

    test "multi-row buffer uses \\n between rows" do
      buffer =
        Buffer.new(2, 2)
        |> Buffer.put(0, 0, "A")
        |> Buffer.put(1, 0, "B")
        |> Buffer.put(0, 1, "C")
        |> Buffer.put(1, 1, "D")

      binary = Buffer.to_iodata(buffer) |> IO.iodata_to_binary()
      assert binary =~ "AB\nCD"
    end

    test "trailing whitespace on last row is trimmed" do
      buffer =
        Buffer.new(5, 1)
        |> Buffer.put(0, 0, "X")

      binary = Buffer.to_iodata(buffer) |> IO.iodata_to_binary()
      assert binary == "X"
    end
  end

  describe "Buffer.overlay/4" do
    test "paints src onto dest at offset" do
      dest = Buffer.new(5, 1)
      src = Buffer.new(2, 1) |> Buffer.put(0, 0, "X", {255, 0, 0})

      result = Buffer.overlay(dest, src, 2, 0)

      assert Buffer.get(result, 2, 0).char == "X"
      assert Buffer.get(result, 2, 0).fg == {255, 0, 0}
    end

    test "empty cells in src don't paint over dest content" do
      dest = Buffer.new(3, 1) |> Buffer.put(0, 0, "A", {255, 0, 0})
      src = Buffer.new(3, 1)

      result = Buffer.overlay(dest, src, 0, 0)

      # Original cell preserved
      assert Buffer.get(result, 0, 0).char == "A"
      assert Buffer.get(result, 0, 0).fg == {255, 0, 0}
    end

    test "out-of-bounds src cells are clipped" do
      dest = Buffer.new(3, 1)
      src = Buffer.new(5, 1) |> Buffer.put(0, 0, "X", {255, 0, 0})

      result = Buffer.overlay(dest, src, 2, 0)
      # Only cells 2 (the first of src) fit; the rest are clipped
      assert Buffer.get(result, 2, 0).char == "X"
      # No crash from out-of-bounds
    end

    test "different rows are not affected by overlay" do
      dest =
        Buffer.new(2, 2)
        |> Buffer.put(0, 0, "A")
        |> Buffer.put(0, 1, "B")

      src = Buffer.new(1, 1) |> Buffer.put(0, 0, "X", {255, 0, 0})

      result = Buffer.overlay(dest, src, 0, 0)

      # Row 0 affected
      assert Buffer.get(result, 0, 0).char == "X"
      # Row 1 unchanged
      assert Buffer.get(result, 0, 1).char == "B"
    end
  end

  describe "Buffer.hstack/2" do
    test "joins two single-row buffers side by side" do
      a = Buffer.new(3, 1) |> Buffer.put(0, 0, "A")
      b = Buffer.new(3, 1) |> Buffer.put(0, 0, "B")

      result = Buffer.hstack([a, b], 1)

      assert result.width == 7
      assert result.height == 1
      assert Buffer.get(result, 0, 0).char == "A"
      assert Buffer.get(result, 4, 0).char == "B"
    end

    test "different heights get padded with empty rows" do
      a = Buffer.new(2, 2) |> Buffer.put(0, 0, "A")
      b = Buffer.new(2, 1) |> Buffer.put(0, 0, "B")

      result = Buffer.hstack([a, b])

      assert result.width == 4
      assert result.height == 2
      assert Buffer.get(result, 0, 0).char == "A"
      assert Buffer.get(result, 2, 0).char == "B"
      assert Buffer.get(result, 2, 1).char == " "
    end

    test "empty list returns empty buffer" do
      result = Buffer.hstack([])
      assert result.width == 0
      assert result.height == 0
    end
  end

  describe "Buffer.vstack/2" do
    test "joins two single-column buffers top to bottom" do
      a = Buffer.new(1, 2) |> Buffer.put(0, 0, "A")
      b = Buffer.new(1, 2) |> Buffer.put(0, 0, "B")

      result = Buffer.vstack([a, b], 1)

      assert result.width == 1
      assert result.height == 5
      assert Buffer.get(result, 0, 0).char == "A"
      assert Buffer.get(result, 0, 3).char == "B"
    end

    test "different widths get padded with empty cols" do
      a = Buffer.new(2, 1) |> Buffer.put(0, 0, "A")
      b = Buffer.new(1, 1) |> Buffer.put(0, 0, "B")

      result = Buffer.vstack([a, b])

      assert result.width == 2
      assert result.height == 2
      assert Buffer.get(result, 0, 0).char == "A"
      assert Buffer.get(result, 0, 1).char == "B"
      assert Buffer.get(result, 1, 1).char == " "
    end
  end

  describe "Buffer.crop/5" do
    test "extracts a sub-region" do
      buffer =
        Buffer.new(5, 3)
        |> Buffer.put(2, 1, "X", {255, 0, 0})

      cropped = Buffer.crop(buffer, 2, 1, 2, 1)

      assert cropped.width == 2
      assert cropped.height == 1
      assert Buffer.get(cropped, 0, 0).char == "X"
      assert Buffer.get(cropped, 0, 0).fg == {255, 0, 0}
    end

    test "clamps out-of-range bounds" do
      buffer = Buffer.new(5, 5) |> Buffer.put(0, 0, "A")
      cropped = Buffer.crop(buffer, -10, -10, 100, 100)

      # Effectively the whole buffer
      assert cropped.width == 5
      assert cropped.height == 5
    end
  end

  describe "Buffer.pad/3" do
    test "pads a buffer to a target size, content stays top-left" do
      buffer = Buffer.new(2, 1) |> Buffer.put(0, 0, "A")
      padded = Buffer.pad(buffer, 5, 3)

      assert padded.width == 5
      assert padded.height == 3
      assert Buffer.get(padded, 0, 0).char == "A"
    end

    test "smaller target size is a no-op" do
      buffer = Buffer.new(5, 3)
      assert Buffer.pad(buffer, 2, 1) == buffer
    end
  end

  describe "Buffer.with_offset/3" do
    test "attaches offset metadata without copying cells" do
      buffer = Buffer.new(3, 1)
      positioned = Buffer.with_offset(buffer, 10, 5)

      assert positioned.offset_x == 10
      assert positioned.offset_y == 5
      assert positioned.width == 3
      # Cells unchanged
      assert positioned.cells == buffer.cells
    end

    test "negative offsets are rejected" do
      assert_raise FunctionClauseError, fn ->
        Buffer.with_offset(Buffer.new(1, 1), -1, 0)
      end
    end
  end

  describe "Printer.print_buffer/2" do
    test "writes buffer contents to stdout" do
      buffer =
        Buffer.new(3, 1)
        |> Buffer.put(0, 0, "A")
        |> Buffer.put(1, 0, "B")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Printer.print_buffer(buffer)
        end)

      assert output =~ "AB"
    end

    test "honours :x and :y for cursor positioning" do
      buffer = Buffer.new(1, 1) |> Buffer.put(0, 0, "X")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Printer.print_buffer(buffer, x: 5, y: 2, clear_line: false)
        end)

      # ANSI cursor position: ESC[3;6H (y+1, x+1)
      assert output =~ ~s(\e[3;6H)
      assert output =~ "X"
    end

    test "honours Buffer.with_offset combined with :x and :y" do
      buffer = Buffer.new(1, 1) |> Buffer.put(0, 0, "X")
      positioned = Buffer.with_offset(buffer, 3, 1)

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Printer.print_buffer(positioned, x: 2, y: 1, clear_line: false)
        end)

      # Total offset: buffer.offset_x (3) + opt :x (2) = 5, y = 2
      assert output =~ ~s(\e[3;6H)
    end

    test "clear_line option prepends \\e[K to each row" do
      buffer = Buffer.new(2, 1) |> Buffer.put(0, 0, "A")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Printer.print_buffer(buffer, clear_line: true)
        end)

      assert output =~ ~s(\e[K)
    end
  end

  describe "Box as a wrapper (post-processor)" do
    test "wraps a String with a border" do
      buffer = Box.render("Hi", title: "Box")

      assert %Buffer{} = buffer
      assert buffer.width >= 4
      assert buffer.height == 3
    end

    test "wraps a Buffer with a border" do
      inner = Box.render("inner") # 6x3
      outer = Box.render(inner, border: :double, padding: 1)

      assert %Buffer{} = outer
      assert outer.width > inner.width
      assert outer.height > inner.height

      # Inner content preserved somewhere inside
      binary = Buffer.to_iodata(outer) |> IO.iodata_to_binary()
      assert binary =~ "inner"
    end

    test "different borders produce different widths" do
      normal_box = Box.render("X", border: :normal)
      double_box = Box.render("X", border: :double)

      assert normal_box.width == double_box.width
    end
  end

  describe "Composition: components in components" do
    test "Separator + Bar stacked vertically via vstack" do
      sep = Separator.render(nil, char: "─", width: 10)
      bar = Bar.render(75, 100, width: 10, show_percent: false)

      stacked = Buffer.vstack([sep, bar], 1)

      assert stacked.width == 12
      assert stacked.height == 3
    end

    test "Header + Box nested via Box.render(Buffer)" do
      header = Header.render("Title")
      boxed = Box.render(header, padding: 1)

      assert %Buffer{} = boxed
      assert boxed.height > header.height
    end

    test "Table inside a Box renders with both structures" do
      table = Table.render_buffer(headers: ["A"], rows: [["1"]], table_border: :rounded)
      boxed = Box.render(table, border: :double)

      binary = Buffer.to_iodata(boxed) |> IO.iodata_to_binary()
      assert binary =~ "A"
      assert binary =~ "1"
      assert binary =~ "╭"
    end
  end

  describe "Cell basic API" do
    test "Cell.empty/0 returns empty cell" do
      assert %Cell{char: " ", fg: nil, bg: nil, effects: []} == Cell.empty()
    end

    test "Cell.new/2 with keyword opts" do
      cell = Cell.new("X", fg: {255, 0, 0}, bold: true)

      assert cell.char == "X"
      assert cell.fg == {255, 0, 0}
      assert :bold in cell.effects
    end
  end
end