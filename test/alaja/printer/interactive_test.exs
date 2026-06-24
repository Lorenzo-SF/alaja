defmodule Alaja.Printer.InteractiveTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Alaja.Printer.Interactive

  describe "question/2" do
    test "returns user input" do
      # Mock IO.gets with provided input
      _ =
        capture_io([input: "hello\n"], fn ->
          result = Interactive.question("Name:")
          assert result == "hello"
        end)
    end
  end

  describe "yesno/2" do
    test "returns :yes for Y" do
      capture_io([input: "Y\n"], fn ->
        assert Interactive.yesno("Continue?") == :yes
      end)
    end

    test "returns :no for N" do
      capture_io([input: "N\n"], fn ->
        assert Interactive.yesno("Continue?") == :no
      end)
    end

    test "uses default for empty input" do
      capture_io([input: "\n"], fn ->
        assert Interactive.yesno("Continue?", default: :yes) == :yes
      end)
    end
  end

  describe "menu/3" do
    test "displays options" do
      output =
        capture_io(fn ->
          Interactive.menu("Choose:", [{"A", :a}, {"B", :b}])
        end)

      assert String.contains?(output, "Choose:")
      assert String.contains?(output, "A")
      assert String.contains?(output, "B")
    end
  end
end
