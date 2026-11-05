defmodule Alaja.Components.Table.CalculatorTest do
  use ExUnit.Case, async: true

  alias Alaja.Components.Table.Calculator

  describe "visible_length/1" do
    test "ASCII printable counts as 1 cell per char" do
      assert Calculator.visible_length("hello") == 5
      assert Calculator.visible_length("a") == 1
      assert Calculator.visible_length("123!@#") == 6
    end

    test "empty string is 0 cells" do
      assert Calculator.visible_length("") == 0
    end

    test "ANSI escapes are stripped before measuring" do
      assert Calculator.visible_length("\e[31mred\e[0m") == 3
      assert Calculator.visible_length("\e[1;38;2;100;150;255mhi\e[0m") == 2
    end

    test "CJK ideographs count as 2 cells each" do
      assert Calculator.visible_length("你好") == 4
      assert Calculator.visible_length("こんにちは") == 10
      assert Calculator.visible_length("안녕") == 4
    end

    test "mixed ASCII + CJK is sum of widths" do
      assert Calculator.visible_length("Hi 你好") == 7
      assert Calculator.visible_length("name 你好 status") == 16
    end

    test "combining marks are zero-width" do
      # "á" can be a single codepoint (U+00E1) or "a" + combining acute (U+0301).
      # Both forms render as 1 cell.
      assert Calculator.visible_length("á") == 1
      assert Calculator.visible_length("a\u0301") == 1
    end

    test "zero-width joiner is zero-width" do
      # "a\u200Db" has a zero-width joiner between ASCII chars; visible
      # width stays at 2.
      assert Calculator.visible_length("a\u200Db") == 2
    end
  end

  describe "pad_visible/2 + pad_visible_leading/2 + center_text/2" do
    test "CJK pads to visible cell width, not grapheme count" do
      padded = Calculator.pad_visible("你好", 6)
      assert Alaja.Text.width(padded) == 6
      assert String.starts_with?(padded, "你好")
    end

    test "center_text centers by visible cell width" do
      centered = Calculator.center_text("hi", 6)
      assert Alaja.Text.width(centered) == 6
    end
  end

  describe "calculate_column_widths/1 with CJK content" do
    test "column with CJK widens to fit double-width chars" do
      data = [["name"], ["Alice"], ["你好"]]
      widths = Calculator.calculate_column_widths(data)
      # 4 ("name") vs 5 ("Alice") vs 4 ("你好") -> max = 5
      assert widths == [5]
    end

    test "mixed ASCII + CJK across rows picks the visual maximum" do
      data = [
        ["A", "B"],
        ["你好", "hi"]
      ]

      widths = Calculator.calculate_column_widths(data)
      # col 0: "A"=1, "你好"=4 -> 4; col 1: "B"=1, "hi"=2 -> 2
      assert widths == [4, 2]
    end
  end
end
