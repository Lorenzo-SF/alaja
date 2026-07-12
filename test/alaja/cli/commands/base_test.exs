defmodule BaseTest do
  use ExUnit.Case, async: true

  alias Alaja.CLI.Commands.Base

  describe "parse_color/1" do
    test "returns nil for nil" do
      assert Base.parse_color(nil) == nil
    end

    test "parses a known color string" do
      assert Base.parse_color("red") == {255, 0, 0}
    end

    test "returns nil for unknown color" do
      assert Base.parse_color("notacolor") == nil
    end
  end

  describe "parse_color_list/1" do
    test "returns nil for nil" do
      assert Base.parse_color_list(nil) == nil
    end

    test "parses a semicolon separated list of colors" do
      # red => {255,0,0}, #00FF00 => {0,255,0}
      assert Base.parse_color_list("red;#00FF00") == {:ok, [{255, 0, 0}, {0, 255, 0}]}
    end
  end

  describe "parse_align/1" do
    test "returns nil for nil" do
      assert Base.parse_align(nil) == nil
    end

    test "returns atom unchanged" do
      assert Base.parse_align(:left) == :left
    end

    test "converts binary to atom (existing)" do
      assert Base.parse_align("left") == {:ok, :left}
    end

    test "returns error on non-existing atom" do
      assert Base.parse_align("foobar") == {:error, "atom 'foobar' does not exist"}
    end
  end

  describe "parse_align_list/1" do
    test "returns nil for nil" do
      assert Base.parse_align_list(nil) == nil
    end

    test "splits and maps to atoms" do
      assert Base.parse_align_list("left,center,right") |> Enum.sort() == [{:ok, :center}, {:ok, :left}, {:ok, :right}]
    end
  end

  describe "parse_effects/1" do
    test "returns nil for nil" do
      assert Base.parse_effects(nil) == nil
    end

    test "splits and maps to atoms" do
      assert Base.parse_effects("bold,italic") == [{:ok, :bold}, {:ok, :italic}]
    end
  end

  describe "parse_effects_list/1" do
    test "returns nil for nil" do
      assert Base.parse_effects_list(nil) == nil
    end

    test "equivalent to parse_effects" do
      assert Base.parse_effects_list("bold,italic") == Base.parse_effects("bold,italic")
    end
  end

  describe "term_width/0" do
    test "returns a positive integer" do
      width = Base.term_width()
      assert is_integer(width)
      assert width > 0
    end
  end

  describe "apply_align/2" do
    test "does nothing for left" do
      assert Base.apply_align("abcd", :left) == "abcd"
    end

    test "centers string without ANSI" do
      width = Base.term_width()
      visible_len = 4
      padding = div(width - visible_len, 2)
      padded = Base.apply_align("abcd", :center)
      assert String.starts_with?(padded, String.duplicate(" ", padding))
      assert String.slice(padded, padding, 4) == "abcd"
    end

    test "right aligns string without ANSI" do
      width = Base.term_width()
      visible_len = 4
      padding = width - visible_len
      padded = Base.apply_align("abcd", :right)
      assert String.starts_with?(padded, String.duplicate(" ", padding))
      assert String.slice(padded, padding, 4) == "abcd"
    end
  end

  describe "parse_border_opt/1" do
    test "parses existing atom" do
      assert Base.parse_border_opt("single") == :single
    end

    test "returns :normal for non-existing atom" do
      assert Base.parse_border_opt("foobar") == :normal
    end
  end
end
