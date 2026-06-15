defmodule Alaja.CellTest do
  use ExUnit.Case
  alias Alaja.Cell

  describe "empty" do
    test "creates an empty cell" do
      cell = Cell.empty()
      assert cell.char == " "
      assert cell.fg == nil
      assert cell.bg == nil
      assert cell.effects == []
    end
  end

  describe "new" do
    test "creates cell with default values" do
      cell = Cell.new()
      assert cell.char == " "
      assert cell.fg == nil
      assert cell.bg == nil
      assert cell.effects == []
    end

    test "creates cell with character only" do
      cell = Cell.new("X")
      assert cell.char == "X"
    end

    test "creates cell with foreground color" do
      cell = Cell.new("A", {255, 0, 0})
      assert cell.char == "A"
      assert cell.fg == {255, 0, 0}
    end

    test "creates cell with fg and bg" do
      cell = Cell.new("A", {255, 0, 0}, {0, 0, 255})
      assert cell.fg == {255, 0, 0}
      assert cell.bg == {0, 0, 255}
    end

    test "creates cell with effects keyword" do
      cell = Cell.new("A", fg: {255, 0, 0}, effects: [:bold])
      assert cell.fg == {255, 0, 0}
      assert :bold in cell.effects
    end

    test "creates cell with bold option" do
      cell = Cell.new("A", bold: true)
      assert :bold in cell.effects
    end

    test "creates cell with italic option" do
      cell = Cell.new("A", italic: true)
      assert :italic in cell.effects
    end

    test "creates cell with underline option" do
      cell = Cell.new("A", underline: true)
      assert :underline in cell.effects
    end

    test "creates cell with dim option" do
      cell = Cell.new("A", dim: true)
      assert :dim in cell.effects
    end
  end

  describe "equal?" do
    test "two identical cells are equal" do
      a = Cell.new("A", {255, 0, 0})
      b = Cell.new("A", {255, 0, 0})
      assert Cell.equal?(a, b) == true
    end

    test "different characters are not equal" do
      a = Cell.new("A")
      b = Cell.new("B")
      assert Cell.equal?(a, b) == false
    end

    test "different fg colors are not equal" do
      a = Cell.new("A", {255, 0, 0})
      b = Cell.new("A", {0, 255, 0})
      assert Cell.equal?(a, b) == false
    end

    test "different bg colors are not equal" do
      a = Cell.new("A", nil, {0, 0, 0})
      b = Cell.new("A", nil, {255, 255, 255})
      assert Cell.equal?(a, b) == false
    end
  end

  describe "merge" do
    test "overlay replaces char when not space" do
      base = Cell.new("A")
      overlay = Cell.new("B")
      merged = Cell.merge(base, overlay)
      assert merged.char == "B"
    end

    test "base char preserved when overlay is space" do
      base = Cell.new("A")
      overlay = Cell.new(" ")
      merged = Cell.merge(base, overlay)
      assert merged.char == "A"
    end

    test "overlay fg takes precedence" do
      base = Cell.new("A", {255, 0, 0})
      overlay = Cell.new("B", {0, 255, 0})
      merged = Cell.merge(base, overlay)
      assert merged.fg == {0, 255, 0}
    end

    test "nil fg falls back to base" do
      base = Cell.new("A", {255, 0, 0})
      overlay = Cell.new("B")
      merged = Cell.merge(base, overlay)
      assert merged.fg == {255, 0, 0}
    end
  end

  describe "apply_effect" do
    test "adds effect to cell" do
      cell = Cell.new("A")
      result = Cell.apply_effect(cell, :bold)
      assert :bold in result.effects
    end

    test "does not duplicate effects" do
      cell = Cell.new("A", effects: [:bold])
      result = Cell.apply_effect(cell, :bold)
      assert length(result.effects) == 1
    end
  end

  describe "visual_width" do
    test "ASCII character has width 1" do
      cell = Cell.new("A")
      assert Cell.visual_width(cell) == 1
    end

    test "space has width 1" do
      cell = Cell.new(" ")
      assert Cell.visual_width(cell) == 1
    end
  end

  describe "to_ansi" do
    test "empty cell returns space" do
      cell = Cell.empty()
      result = Cell.to_ansi(cell)
      assert to_string(result) == " "
    end

    test "plain cell returns char" do
      cell = Cell.new("X")
      result = Cell.to_ansi(cell)
      assert to_string(result) == "X"
    end

    test "cell with fg produces ANSI" do
      cell = Cell.new("X", {255, 0, 0})
      result = Cell.to_ansi(cell) |> to_string()
      assert result =~ "38;2;255;0;0"
    end

    test "cell with bg produces ANSI" do
      cell = Cell.new("X", nil, {0, 0, 255})
      result = Cell.to_ansi(cell) |> to_string()
      assert result =~ "48;2;0;0;255"
    end
  end
end
