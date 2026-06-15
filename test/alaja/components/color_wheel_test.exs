defmodule Alaja.Components.ColorWheelTest do
  use ExUnit.Case, async: true

  alias Alaja.Components.ColorWheel

  describe "compute_harmony/2" do
    test "returns complementary colors" do
      result = ColorWheel.compute_harmony({255, 0, 0}, :complementary)
      assert is_list(result)
      assert length(result) == 1
    end

    test "returns analogous colors" do
      result = ColorWheel.compute_harmony({255, 0, 0}, :analogous)
      assert length(result) == 2
    end

    test "returns triad colors" do
      result = ColorWheel.compute_harmony({255, 0, 0}, :triad)
      assert length(result) == 2
    end

    test "returns square colors" do
      result = ColorWheel.compute_harmony({255, 0, 0}, :square)
      assert length(result) == 3
    end

    test "returns monochromatic colors" do
      result = ColorWheel.compute_harmony({255, 0, 0}, :monochromatic)
      assert length(result) == 5
    end

    test "returns split_complementary colors" do
      result = ColorWheel.compute_harmony({255, 0, 0}, :split_complementary)
      assert length(result) == 2
    end

    test "returns compound colors" do
      result = ColorWheel.compute_harmony({255, 0, 0}, :compound)
      assert length(result) == 4
    end

    test "returns empty list for unknown type" do
      assert ColorWheel.compute_harmony({255, 0, 0}, :unknown) == []
    end
  end

  describe "extract_angles/1" do
    test "extracts hue angles from RGB tuples" do
      angles = ColorWheel.extract_angles([{255, 0, 0}, {0, 255, 0}, {0, 0, 255}])
      assert length(angles) == 3
      assert Enum.all?(angles, &is_number/1)
    end
  end

  describe "harmony_display_name/1" do
    test "returns correct names for all types" do
      assert ColorWheel.harmony_display_name(:complementary) == "COMPLEMENTARIA"
      assert ColorWheel.harmony_display_name(:analogous) == "ANÁLOGA"
      assert ColorWheel.harmony_display_name(:triad) == "TRÍADA"
      assert ColorWheel.harmony_display_name(:square) == "CUADRADA"
      assert ColorWheel.harmony_display_name(:monochromatic) == "MONOCROMÁTICA"
      assert ColorWheel.harmony_display_name(:split_complementary) == "SPLIT-COMPLEMENTARIA"
      assert ColorWheel.harmony_display_name(:compound) == "COMPUESTA"
      assert ColorWheel.harmony_display_name(:whatever) == "ARMONÍA"
    end
  end

  describe "get_ascii_wheel_lines/3" do
    test "returns list of strings forming the wheel" do
      angles = [0.0, 120.0, 240.0]
      lines = ColorWheel.get_ascii_wheel_lines(angles, :triad, radius: 5)
      assert is_list(lines)
      assert lines != []
      assert Enum.all?(lines, &is_binary/1)
    end

    test "renders with default radius" do
      lines = ColorWheel.get_ascii_wheel_lines([0.0], :complementary)
      assert Enum.count(lines) == 10
    end

    test "inserts harmony label in center line" do
      lines = ColorWheel.get_ascii_wheel_lines([0.0, 180.0], :complementary, radius: 8)
      center = div(length(lines), 2)
      center_line = Enum.at(lines, center)
      assert String.contains?(center_line, "COMPLEMENTARIA")
    end
  end

  describe "show_color_info/2" do
    test "outputs color info to stdout" do
      output = capture_io(fn -> ColorWheel.show_color_info({186, 218, 85}) end)
      assert String.contains?(output, "████")
    end

    test "shows formats when enabled" do
      output =
        capture_io(fn ->
          ColorWheel.show_color_info({255, 0, 0}, show_formats: true)
        end)

      assert String.contains?(output, "HEX")
      assert String.contains?(output, "RGB")
    end

    test "shows variants when enabled" do
      output =
        capture_io(fn ->
          ColorWheel.show_color_info({255, 0, 0}, show_variants: true)
        end)

      assert String.contains?(output, "Base")
    end
  end

  describe "show_harmony_ring/3" do
    test "renders harmony ring to stdout" do
      output = capture_io(fn -> ColorWheel.show_harmony_ring({255, 0, 0}, :triad) end)
      assert String.contains?(output, "TRÍADA")
    end
  end

  describe "show_swatches/2" do
    test "renders color swatches" do
      output =
        capture_io(fn ->
          ColorWheel.show_swatches([{255, 0, 0}, {0, 255, 0}])
        end)

      assert String.contains?(output, "████████")
    end
  end

  describe "show_gradient/3" do
    test "renders gradient between two colors" do
      output =
        capture_io(fn ->
          ColorWheel.show_gradient({255, 0, 0}, {0, 0, 255}, 10)
        end)

      assert String.contains?(output, "██")
    end
  end

  describe "render_color_formats/1" do
    test "outputs all format conversions" do
      output = capture_io(fn -> ColorWheel.render_color_formats({186, 218, 85}) end)
      assert String.contains?(output, "HEX")
      assert String.contains?(output, "RGB")
      assert String.contains?(output, "ARGB")
      assert String.contains?(output, "HSL")
      assert String.contains?(output, "HSV")
      assert String.contains?(output, "CMYK")
      assert String.contains?(output, "XTerm256")
    end
  end

  describe "render_color_variants/1" do
    test "outputs lighter and darker variants" do
      output = capture_io(fn -> ColorWheel.render_color_variants({128, 128, 128}) end)
      assert String.contains?(output, "+50%")
      assert String.contains?(output, "-50%")
      assert String.contains?(output, "Base")
    end
  end

  describe "render_swatch_list/1" do
    test "renders a list of swatches with hex labels" do
      output =
        capture_io(fn ->
          ColorWheel.render_swatch_list([{255, 0, 0}, {0, 255, 0}])
        end)

      assert String.contains?(output, "rgb(255,0,0)")
      assert String.contains?(output, "rgb(0,255,0)")
    end
  end

  defp capture_io(fun), do: ExUnit.CaptureIO.capture_io(fun)
end
