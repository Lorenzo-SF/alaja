defmodule Alaja.Components.PulsarImageTest do
  @moduledoc """
  Pulsar image mode: the image must be contained (aspect ratio preserved,
  never stretched to the whole box) and positioned inside the pulsar like
  text, using `content_position_x/y`.
  """
  use ExUnit.Case, async: true

  alias Alaja.Components.Pulsar
  alias Alaja.ImageRenderer.PNG

  # Píxel "pulso" (fuera de la imagen): un color reconocible y distinto.
  @pulse_color {10, 20, 30}

  defp fixture_png(pixels) do
    height = length(pixels)
    width = length(List.first(pixels, []))

    path =
      Path.join(System.tmp_dir!(), "pulsar_fixture_#{System.unique_integer([:positive])}.png")

    File.write!(path, PNG.generate_rgb(pixels, width, height))
    on_exit(fn -> File.rm(path) end)
    path
  end

  describe "contain (aspect ratio preserved)" do
    test "image taller than the box is rescaled by height, not stretched" do
      # 1x6 (aspect 6) en box 12x4 -> contain: ancho 1, alto 3, centrada en x=5, y=0
      path = fixture_png(List.duplicate([{0, 255, 0}], 6))

      assert {:ok, frame} =
               Pulsar.render_frame_pixels(path, 0,
                 width: 12,
                 height: 4,
                 colors: [@pulse_color]
               )

      assert length(frame) == 4
      assert Enum.all?(frame, &(length(&1) == 12))
      # imagen centrada: x = div(12 - 1, 2) = 5, y = div(4 - 3, 2) = 0
      assert Enum.at(frame, 0) |> Enum.at(5) == {0, 255, 0}
      # fuera de la imagen -> pulso, no verde
      assert Enum.at(frame, 0) |> Enum.at(0) != {0, 255, 0}
      assert Enum.at(frame, 3) |> Enum.at(11) != {0, 255, 0}
    end

    test "landscape image inside a taller box leaves room (centered vertically)" do
      # 1x2 (aspect 2) en box 12x8 -> th = round(12 * 2 / 2) = 12 > 8
      # -> rescale por alto: ancho = round(12 * 8 / 12) = 8, alto 8
      path = fixture_png(List.duplicate([{0, 255, 0}], 2))

      assert {:ok, frame} =
               Pulsar.render_frame_pixels(path, 0,
                 width: 12,
                 height: 8,
                 colors: [@pulse_color]
               )

      # imagen 8x8 centrada: x = div(12 - 8, 2) = 2, y = div(8 - 8, 2) = 0
      assert Enum.at(frame, 0) |> Enum.at(2) == {0, 255, 0}
      assert Enum.at(frame, 7) |> Enum.at(9) == {0, 255, 0}
      # fuera de la imagen: columna 0 -> pulso
      assert Enum.at(frame, 0) |> Enum.at(0) != {0, 255, 0}
      assert Enum.at(frame, 0) |> Enum.at(11) != {0, 255, 0}
    end

    test "image shorter than the box is not stretched vertically" do
      # 1x1 (aspect 1) en box 12x8 -> th = round(12 * 1 / 2) = 6 -> imagen 12x6
      path = fixture_png([[{0, 255, 0}]])

      assert {:ok, frame} =
               Pulsar.render_frame_pixels(path, 0,
                 width: 12,
                 height: 8,
                 colors: [@pulse_color]
               )

      # centrada: y = div(8 - 6, 2) = 1 -> filas 1..6
      assert Enum.at(frame, 0) |> Enum.at(0) != {0, 255, 0}
      assert Enum.at(frame, 1) |> Enum.at(0) == {0, 255, 0}
      assert Enum.at(frame, 6) |> Enum.at(0) == {0, 255, 0}
      assert Enum.at(frame, 7) |> Enum.at(0) != {0, 255, 0}
    end
  end

  describe "positioning inside the pulsar (content_position_x/y)" do
    setup do
      # 1x2 verde (aspect 2) -> en box 12x8 la imagen contenida es 8x8
      %{path: fixture_png(List.duplicate([{0, 255, 0}], 2))}
    end

    test "content_position_x/y place the image at the requested offset", %{path: path} do
      assert {:ok, frame} =
               Pulsar.render_frame_pixels(path, 0,
                 width: 12,
                 height: 8,
                 content_position_x: 1,
                 content_position_y: 2,
                 colors: [@pulse_color]
               )

      # imagen 8x8 en (1, 2) -> dentro del box (recortada por abajo): filas 2..7, columnas 1..8
      assert Enum.at(frame, 2) |> Enum.at(1) == {0, 255, 0}
      assert Enum.at(frame, 7) |> Enum.at(8) == {0, 255, 0}
      # fuera de la imagen
      assert Enum.at(frame, 0) |> Enum.at(0) != {0, 255, 0}
      assert Enum.at(frame, 1) |> Enum.at(0) != {0, 255, 0}
      assert Enum.at(frame, 2) |> Enum.at(0) != {0, 255, 0}
    end
  end
end
