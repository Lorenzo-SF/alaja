defmodule Alaja.ImageRendererTest do
  use ExUnit.Case, async: true

  alias Alaja.ImageRenderer

  describe "render_file/2" do
    test "returns error when file does not exist" do
      assert ImageRenderer.render_file("/nonexistent/path/to/file.png") ==
               {:error, :file_not_found}
    end

    test "returns error for nonexistent file with custom width and height" do
      assert ImageRenderer.render_file("/nonexistent.png", width: 80, height: 24) ==
               {:error, :file_not_found}
    end

    test "returns unsupported for unknown protocol" do
      assert ImageRenderer.render_file("/etc/passwd", protocol: :unknown_protocol) ==
               :unsupported
    end

    test "returns unsupported for unknown protocol with options" do
      assert ImageRenderer.render_file("/etc/passwd",
               protocol: :unknown,
               width: 40,
               height: 20
             ) == :unsupported
    end

    test "uses default width and height when not specified" do
      File.write("/tmp/test_image.png", <<137, 80, 78, 71, 13, 10, 26, 10>>)
      result = ImageRenderer.render_file("/tmp/test_image.png", protocol: :ascii)
      assert result in [:ok, :unsupported]
      File.rm("/tmp/test_image.png")
    end

    test "handles explicit nil protocol gracefully" do
      File.write("/tmp/test_nil.png", <<137, 80, 78, 71, 13, 10, 26, 10>>)
      result = ImageRenderer.render_file("/tmp/test_nil.png", protocol: nil)
      assert result in [:ok, :unsupported]
      File.rm("/tmp/test_nil.png")
    end
  end

  describe "render/2" do
    test "returns unsupported for sixel protocol" do
      pixels = [[{255, 0, 0}, {0, 255, 0}], [{0, 0, 255}, {255, 255, 0}]]
      assert ImageRenderer.render(pixels, protocol: :sixel) == :unsupported
    end

    test "returns unsupported for ascii protocol" do
      pixels = [[{255, 0, 0}]]
      assert ImageRenderer.render(pixels, protocol: :ascii) == :unsupported
    end

    test "returns unsupported for unknown protocol" do
      pixels = [[{255, 0, 0}]]
      assert ImageRenderer.render(pixels, protocol: :totally_unknown) == :unsupported
    end

    test "handles empty pixels list" do
      result = ImageRenderer.render([], protocol: :ascii)
      assert result == :unsupported
    end

    test "handles single row pixels" do
      pixels = [[{255, 0, 0}, {0, 255, 0}, {0, 0, 255}]]
      result = ImageRenderer.render(pixels, protocol: :kitty)
      assert result == :ok
    end

    test "handles single pixel" do
      pixels = [[{255, 255, 255}]]
      result = ImageRenderer.render(pixels, protocol: :kitty)
      assert result == :ok
    end

    test "handles default width when pixels list is empty" do
      result = ImageRenderer.render([], protocol: :kitty)
      assert result == :ok
    end

    test "respects width option" do
      pixels = [[{255, 0, 0}, {0, 255, 0}, {0, 0, 255}]]
      result = ImageRenderer.render(pixels, protocol: :kitty, width: 10)
      assert result == :ok
    end

    test "respects height option" do
      pixels = [[{255, 0, 0}], [{0, 255, 0}], [{0, 0, 255}]]
      result = ImageRenderer.render(pixels, protocol: :kitty, height: 3)
      assert result == :ok
    end

    test "handles grayscale pixels" do
      pixels = [
        [{128, 128, 128}, {64, 64, 64}],
        [{192, 192, 192}, {32, 32, 32}]
      ]

      result = ImageRenderer.render(pixels, protocol: :iterm2)
      assert result == :ok
    end

    test "handles full color range pixels" do
      pixels = [
        [{0, 0, 0}, {255, 255, 255}],
        [{255, 0, 0}, {0, 255, 0}]
      ]

      result = ImageRenderer.render(pixels, protocol: :kitty)
      assert result == :ok
    end

    test "renders with iterm2 protocol" do
      pixels = [[{255, 128, 0}, {0, 128, 255}]]
      result = ImageRenderer.render(pixels, protocol: :iterm2, width: 2, height: 1)
      assert result == :ok
    end

    test "uses nil protocol defaults to detect_protocol" do
      pixels = [[{100, 100, 100}]]
      protocol = ImageRenderer.detect_protocol()
      result = ImageRenderer.render(pixels)
      assert result in [:ok, :unsupported]
      assert protocol in [:kitty, :iterm2, :sixel, :ascii]
    end
  end

  describe "detect_protocol/0" do
    test "returns a known protocol atom" do
      protocol = ImageRenderer.detect_protocol()
      assert protocol in [:kitty, :iterm2, :sixel, :ascii]
    end

    test "returns consistent result on multiple calls" do
      protocol1 = ImageRenderer.detect_protocol()
      protocol2 = ImageRenderer.detect_protocol()
      protocol3 = ImageRenderer.detect_protocol()

      assert protocol1 == protocol2
      assert protocol2 == protocol3
    end
  end

  describe "generate_png/3" do
    test "generates a valid PNG binary from pixel data" do
      pixels = [
        [{255, 0, 0}, {0, 255, 0}],
        [{0, 0, 255}, {255, 255, 0}]
      ]

      png = ImageRenderer.generate_png(pixels, 2, 2)

      assert binary_part(png, 0, 8) == <<137, 80, 78, 71, 13, 10, 26, 10>>
      assert byte_size(png) > 50
    end

    test "generates PNG with correct dimensions" do
      pixels = for _y <- 0..9, do: for(_x <- 0..19, do: {128, 64, 32})
      png = ImageRenderer.generate_png(pixels, 20, 10)

      ihdr_data = binary_part(png, 16, 8)
      <<w::big-size(32), h::big-size(32)>> = ihdr_data

      assert w == 20
      assert h == 10
    end

    test "generates PNG with 1x1 dimensions" do
      pixels = [[{255, 255, 255}]]
      png = ImageRenderer.generate_png(pixels, 1, 1)
      assert byte_size(png) > 50
    end

    test "generates PNG with larger dimensions" do
      pixels = for y <- 0..49, do: for(x <- 0..79, do: {x * 3, y * 5, 128})
      png = ImageRenderer.generate_png(pixels, 80, 50)

      ihdr_data = binary_part(png, 16, 8)
      <<w::big-size(32), h::big-size(32)>> = ihdr_data

      assert w == 80
      assert h == 50
    end

    test "handles pixel data larger than dimensions" do
      pixels = [
        [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}],
        [{255, 255, 0}, {255, 0, 255}, {0, 255, 255}],
        [{128, 128, 128}, {64, 64, 64}, {32, 32, 32}]
      ]

      png = ImageRenderer.generate_png(pixels, 2, 2)

      ihdr_data = binary_part(png, 16, 8)
      <<w::big-size(32), h::big-size(32)>> = ihdr_data

      assert w == 2
      assert h == 2
    end

    test "handles pixel data smaller than dimensions" do
      pixels = [[{255, 0, 0}]]
      png = ImageRenderer.generate_png(pixels, 5, 5)

      ihdr_data = binary_part(png, 16, 8)
      <<w::big-size(32), h::big-size(32)>> = ihdr_data

      assert w == 5
      assert h == 5
    end

    test "handles empty rows in pixel data" do
      pixels = [[], [{255, 0, 0}], []]
      png = ImageRenderer.generate_png(pixels, 1, 3)

      ihdr_data = binary_part(png, 16, 8)
      <<w::big-size(32), h::big-size(32)>> = ihdr_data

      assert w == 1
      assert h == 3
    end

    test "PNG has correct chunk structure" do
      pixels = [[{100, 100, 100}]]
      png = ImageRenderer.generate_png(pixels, 1, 1)

      png_header = binary_part(png, 0, 8)
      assert png_header == <<137, 80, 78, 71, 13, 10, 26, 10>>

      assert byte_size(png) > 50
    end

    test "PNG contains IEND chunk" do
      pixels = [[{50, 100, 150}]]
      png = ImageRenderer.generate_png(pixels, 1, 1)

      png_size = byte_size(png)
      assert png_size > 50

      iend_start = png_size - 12

      <<_length::size(32), chunk_type::binary-size(4), _data::binary>> =
        :binary.part(png, iend_start, png_size - iend_start - 4)

      <<_crc::size(32)>> = :binary.part(png, png_size - 4, 4)
      assert chunk_type == "IEND"
    end
  end

  describe "file rendering with protocols" do
    test "kitty protocol returns :ok or :unsupported for valid file" do
      File.write("/tmp/kitty_test.png", <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13>>)

      result =
        ImageRenderer.render_file("/tmp/kitty_test.png", protocol: :kitty, width: 10, height: 10)

      assert result in [:ok, :unsupported]
      File.rm("/tmp/kitty_test.png")
    end

    test "iterm2 protocol returns :ok or :unsupported for valid file" do
      File.write("/tmp/iterm_test.png", <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13>>)
      result = ImageRenderer.render_file("/tmp/iterm_test.png", protocol: :iterm2, width: 10)
      assert result in [:ok, :unsupported]
      File.rm("/tmp/iterm_test.png")
    end

    test "sixel protocol with non-existent img2sixel returns ascii fallback or unsupported" do
      File.write("/tmp/sixel_test.png", <<137, 80, 78, 71, 13, 10, 26, 10>>)

      result =
        ImageRenderer.render_file("/tmp/sixel_test.png", protocol: :sixel, width: 10, height: 10)

      assert result in [:ok, :unsupported]
      File.rm("/tmp/sixel_test.png")
    end

    test "ascii protocol with non-existent img2txt returns unsupported" do
      File.write("/tmp/ascii_test.png", <<137, 80, 78, 71, 13, 10, 26, 10>>)
      result = ImageRenderer.render_file("/tmp/ascii_test.png", protocol: :ascii, width: 10)
      assert result == :unsupported
      File.rm("/tmp/ascii_test.png")
    end

    test "file not found returns error for all protocols" do
      protocols = [:kitty, :iterm2, :sixel, :ascii]

      for protocol <- protocols do
        assert ImageRenderer.render_file("/truly/nonexistent/file.png", protocol: protocol) ==
                 {:error, :file_not_found}
      end
    end
  end
end
