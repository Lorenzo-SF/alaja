defmodule Alaja.CLI.Smoke.ImageAsciiTest do
  @moduledoc """
  Smoke test for `alaja image --to-ascii-art`.

  User reported:

      alaja image --path image.png --to-ascii-art --ascii-style detailed --width 80 --ascii-color

  Expected: ASCII art rendering with colored characters.
  Bug: nothing prints because ImageRenderer.resize_pixels returns numbers
  (not {r,g,b} tuples) which breaks render_pixel/5.
  """
  use Alaja.SmokeCase, async: false

  @test_name "image_ascii_test.exs::ascii art renders"

  setup do
    # Create a tiny test PNG (2x2 with 4 colors)
    test_png = Path.join(System.tmp_dir!(), "alaja_smoke_test.png")

    if not File.exists?(test_png) do
      pixels = [
        [{255, 100, 50}, {100, 200, 30}],
        [{50, 50, 200}, {255, 255, 0}]
      ]

      png_bin = Alaja.ImageRenderer.generate_png(pixels, 2, 2)
      File.write!(test_png, png_bin)
    end

    {:ok, png_path: test_png}
  end

  test "ascii art renders to stdout", %{png_path: png_path} do
    {output, _stderr, exit_code} =
      run_cli([
        "image",
        "--path",
        png_path,
        "--to-ascii-art",
        "--ascii-style",
        "blocks",
        "--width",
        "10",
        "--ascii-color"
      ])

    assert exit_code == 0, "CLI should not crash. Output:\n#{output}"

    # Critical: output should NOT be empty
    assert normalize(output) != "", "ASCII art should produce non-empty output"

    assert_snapshot(@test_name, output, snapshot: "image_ascii_basic")
  end

  test "ascii art without color", %{png_path: png_path} do
    {output, _stderr, exit_code} =
      run_cli([
        "image",
        "--path",
        png_path,
        "--to-ascii-art",
        "--ascii-style",
        "simple",
        "--width",
        "8"
      ])

    assert exit_code == 0, "CLI should not crash. Output:\n#{output}"

    assert normalize(output) != "", "ASCII art should produce non-empty output"

    assert_snapshot(@test_name <> "_no_color", output, snapshot: "image_ascii_no_color")
  end

  test "ascii art detailed style", %{png_path: png_path} do
    {output, _stderr, exit_code} =
      run_cli([
        "image",
        "--path",
        png_path,
        "--to-ascii-art",
        "--ascii-style",
        "detailed",
        "--width",
        "16",
        "--ascii-color"
      ])

    assert exit_code == 0, "CLI should not crash. Output:\n#{output}"

    assert normalize(output) != "", "ASCII art should produce non-empty output"

    assert_snapshot(@test_name <> "_detailed", output, snapshot: "image_ascii_detailed")
  end
end
