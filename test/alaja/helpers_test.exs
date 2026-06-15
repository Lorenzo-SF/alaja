defmodule Alaja.HelpersTest do
  use ExUnit.Case, async: true

  alias Alaja.ANSI
  alias Alaja.Helpers

  describe "braille_spark/2" do
    test "returns string of braille characters" do
      result = Helpers.braille_spark([10, 50, 90, 30], 4)
      assert is_binary(result)
      refute Enum.empty?(String.graphemes(result))
    end

    test "handles empty list" do
      result = Helpers.braille_spark([], 5)
      assert result == ""
    end

    test "handles single value" do
      result = Helpers.braille_spark([50], 1)
      assert Enum.count(String.graphemes(result)) == 1
    end

    test "clamps negative values but keeps positive" do
      result = Helpers.braille_spark([-10, 50], 2)
      assert Enum.count(String.graphemes(result)) == 2
    end

    test "respects width limit" do
      result = Helpers.braille_spark([10, 20, 30, 40, 50], 3)
      assert Enum.count(String.graphemes(result)) == 5
    end

    test "maps low values to empty braille" do
      result = Helpers.braille_spark([0, 5, 10], 3)
      assert String.contains?(result, " ")
    end

    test "maps high values to full braille" do
      result = Helpers.braille_spark([90, 95, 100], 3)
      assert is_binary(result)
    end
  end

  describe "progress_bar/4" do
    test "returns string with bar and percentage" do
      result = Helpers.progress_bar(50, 10, {0, 0, 0}, {255, 255, 255})
      assert is_binary(result)
      assert String.contains?(result, "50%")
    end

    test "clamps percentage to 0-100" do
      result = Helpers.progress_bar(150, 10, {0, 0, 0}, {255, 255, 255})
      assert String.contains?(result, "100%")
    end

    test "handles 0 percent" do
      result = Helpers.progress_bar(0, 10, {0, 0, 0}, {255, 255, 255})
      assert String.contains?(result, "0%")
    end

    test "handles 100 percent" do
      result = Helpers.progress_bar(100, 10, {0, 0, 0}, {255, 255, 255})
      assert String.contains?(result, "100%")
    end

    test "handles negative percentage" do
      result = Helpers.progress_bar(-10, 10, {0, 0, 0}, {255, 255, 255})
      assert String.contains?(result, "0%")
    end

    test "respects width parameter" do
      result_20 = Helpers.progress_bar(50, 20, {0, 0, 0}, {255, 255, 255})
      result_10 = Helpers.progress_bar(50, 10, {0, 0, 0}, {255, 255, 255})
      assert String.length(result_20) > String.length(result_10)
    end

    test "uses color interpolation" do
      result = Helpers.progress_bar(50, 10, {255, 0, 0}, {0, 0, 255})
      assert is_binary(result)
    end
  end

  describe "box/4-5" do
    test "draws box with title" do
      result = Helpers.box(1, 1, 20, 5, "Test")
      assert is_list(result)
      assert length(result) == 6
    end

    test "draws box without title" do
      result = Helpers.box(1, 1, 20, 5)
      assert is_list(result)
      assert length(result) == 5
    end

    test "returns correct number of rows for height" do
      result = Helpers.box(1, 1, 10, 3, "")
      assert length(result) == 3
    end

    test "box contains border characters" do
      result = Helpers.box(1, 1, 10, 3, "")
      assert elem(List.first(result), 2) |> String.contains?("╭")
    end
  end

  describe "double_box/4-5" do
    test "draws double box with title" do
      result = Helpers.double_box(1, 1, 20, 5, "Test")
      assert is_list(result)
      assert length(result) == 6
    end

    test "draws double box without title" do
      result = Helpers.double_box(1, 1, 20, 5)
      assert is_list(result)
      assert length(result) == 5
    end

    test "double box contains double border characters" do
      result = Helpers.double_box(1, 1, 10, 3, "")
      assert elem(List.first(result), 2) |> String.contains?("╔")
    end
  end

  describe "lerp/3" do
    test "interpolates at midpoint" do
      assert Helpers.lerp({0, 0, 0}, {100, 100, 100}, 0.5) == {50, 50, 50}
    end

    test "interpolates at start" do
      assert Helpers.lerp({0, 0, 0}, {100, 100, 100}, 0.0) == {0, 0, 0}
    end

    test "interpolates at end" do
      assert Helpers.lerp({0, 0, 0}, {100, 100, 100}, 1.0) == {100, 100, 100}
    end

    test "handles full black to full white" do
      result = Helpers.lerp({0, 0, 0}, {255, 255, 255}, 0.25)
      assert result == {64, 64, 64}
    end

    test "handles color channels independently" do
      result = Helpers.lerp({255, 0, 0}, {0, 0, 255}, 0.5)
      assert abs(elem(result, 0) - 127) <= 1
      assert elem(result, 1) == 0
      assert abs(elem(result, 2) - 127) <= 1
    end
  end

  describe "edge cases" do
    test "progress_bar with width of 1" do
      result = Helpers.progress_bar(50, 1, {0, 0, 0}, {255, 255, 255})
      assert is_binary(result)
      assert String.contains?(result, "50%")
    end

    test "box with minimum dimensions" do
      result = Helpers.box(1, 1, 3, 3, "")
      assert length(result) == 3
    end

    test "braille_spark with all same values" do
      result = Helpers.braille_spark([50, 50, 50], 3)
      assert Enum.count(String.graphemes(result)) == 3
    end
  end

  describe "safe_string_to_atom/1" do
    test "converts existing atom string to {:ok, atom}" do
      assert Helpers.safe_string_to_atom("left") == {:ok, :left}
    end

    test "returns error for non-existing atom" do
      unique = "atom_#{System.unique_integer([:positive])}"
      assert Helpers.safe_string_to_atom(unique) == {:error, "atom '#{unique}' does not exist"}
    end

    test "converts known reserved atoms" do
      assert Helpers.safe_string_to_atom("nil") == {:ok, nil}
      assert Helpers.safe_string_to_atom("true") == {:ok, true}
      assert Helpers.safe_string_to_atom("false") == {:ok, false}
    end
  end

  # Re-export ANSI helpers that were previously available as deprecated
  # wrappers, so consumers have a clear migration path documented.
  describe "ANSI re-exports" do
    test "ANSI.fg/3 is the canonical entry" do
      assert ANSI.fg(255, 0, 0) =~ "38;2;255;0;0"
    end

    test "ANSI.bold/0 is the canonical entry" do
      assert ANSI.bold() == "\e[1m"
    end
  end
end
