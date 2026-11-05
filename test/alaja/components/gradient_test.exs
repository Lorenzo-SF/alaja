defmodule Alaja.Components.GradientTest do
  use ExUnit.Case

  alias Alaja.Components.Gradient

  # Helper: convert iodata to binary for assertions
  defp to_binary(result) when is_list(result), do: IO.iodata_to_binary(result)
  defp to_binary(result), do: result

  describe "render/2 with vertical gradients" do
    test "gradient up_to_down with single line does not crash" do
      result = Gradient.render("hi", from: "hex:ff0000", to: "hex:0000ff", direction: :up_to_down)
      str = to_binary(result)
      assert is_binary(str)
      # Should contain some ANSI codes
      assert String.contains?(str, "\e[")
    end

    test "gradient down_to_up with single line does not crash" do
      result = Gradient.render("hi", from: "hex:ff0000", to: "hex:0000ff", direction: :down_to_up)
      str = to_binary(result)
      assert is_binary(str)
      assert String.contains?(str, "\e[")
    end

    test "gradient up_to_down with multiple lines works" do
      result =
        Gradient.render("line1\nline2",
          from: "hex:ff0000",
          to: "hex:0000ff",
          direction: :up_to_down
        )

      str = to_binary(result)
      assert is_binary(str)
      assert String.contains?(str, "line1")
      assert String.contains?(str, "line2")
    end

    test "gradient down_to_up with multiple lines works" do
      result =
        Gradient.render("line1\nline2",
          from: "hex:ff0000",
          to: "hex:0000ff",
          direction: :down_to_up
        )

      str = to_binary(result)
      assert is_binary(str)
      assert String.contains?(str, "line1")
      assert String.contains?(str, "line2")
    end
  end

  describe "render/2 with horizontal gradients" do
    test "left_to_right with single line" do
      result =
        Gradient.render("hi", from: "hex:ff0000", to: "hex:0000ff", direction: :left_to_right)

      str = to_binary(result)
      assert is_binary(str)
      assert String.contains?(str, "h")
      assert String.contains?(str, "i")
    end

    test "right_to_left with single line" do
      result =
        Gradient.render("hi", from: "hex:ff0000", to: "hex:0000ff", direction: :right_to_left)

      str = to_binary(result)
      assert is_binary(str)
      assert String.contains?(str, "h")
      assert String.contains?(str, "i")
    end
  end

  describe "render/2 with background gradient" do
    test "vertical bg gradient with single line" do
      result =
        Gradient.render("hi",
          from: "hex:ff0000",
          to: "hex:0000ff",
          direction: :up_to_down,
          bg: true
        )

      str = to_binary(result)
      assert is_binary(str)
      assert String.contains?(str, "\e[")
    end
  end
end
