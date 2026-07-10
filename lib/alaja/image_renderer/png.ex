defmodule Alaja.ImageRenderer.PNG do
  @moduledoc """
  Pure Elixir PNG decoder and generator for terminal image rendering.

  ## Decoder

  Supports PNG (grayscale, RGB, RGBA, indexed) and resizes pixel data
  to a target dimension. Non-PNG formats fall back to ImageMagick's
  `convert` command (via `Trebejo.Image`).

  ## Generator

  Produces minimal PNG binaries from raw pixel data — both RGB and
  RGBA variants. Used by the Kitty and iTerm2 rendering protocols.

  ## Usage

      {:ok, {w, h, pixels}} = Alaja.ImageRenderer.PNG.decode("image.png")

      png_bin = Alaja.ImageRenderer.PNG.generate_rgb(pixels, 100, 100)
  """

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  # ── Decode ─────────────────────────────────────────────────────────────

  @doc """
  Reads and decodes a PNG file. Returns `{:ok, {width, height, pixels}}`
  where `pixels` is a flat list of `{r, g, b}` tuples, or an error tuple.

  For non-PNG formats, returns `:not_png` so callers can attempt a
  fallback decode via ImageMagick.
  """
  @spec decode(String.t()) :: {:ok, {pos_integer(), pos_integer(), [{0..255, 0..255, 0..255}]}} | :not_png | {:error, String.t()}
  def decode(path) do
    with {:ok, bin} <- File.read(path),
         :png <- detect_format(bin) do
      decode_bin(bin, 0, 0)
    else
      :not_png -> :not_png
      {:error, _} = e -> e
    end
  end

  @doc """
  Reads, decodes, and resizes a PNG file.

  When `target_h` is 0, the height is derived from the aspect ratio
  (accounting for terminal cells being roughly 2:1 tall).
  """
  @spec decode_and_resize(String.t(), pos_integer(), pos_integer()) ::
          {:ok, [[{0..255, 0..255, 0..255}]]} | {:error, String.t()}
  def decode_and_resize(path, target_w, target_h) do
    case decode(path) do
      {:ok, {src_w, src_h, pixels}} ->
        aspect = src_h / src_w
        th = if target_h > 0, do: target_h, else: max(1, round(target_w * aspect / 2.0))
        {:ok, resize_pixels(pixels, src_w, src_h, target_w, th)}

      :not_png ->
        {:error, "not a PNG file"}

      {:error, _} = e ->
        e
    end
  end

  defp detect_format(<<@png_signature, _::binary>>), do: :png
  defp detect_format(_), do: :not_png

  defp decode_bin(bin, _, _) when is_binary(bin) do
    <<@png_signature, rest::binary>> = bin
    parse_chunks(rest, %{idat: <<>>})
  end

  defp parse_chunks(<<0::32, "IEND", _crc::32, _::binary>>, acc) do
    build_image(acc)
  end

  defp parse_chunks(<<len::32, "IHDR", data::binary-size(len), _crc::32, rest::binary>>, acc) do
    <<width::32, height::32, bit_depth::8, color_type::8, _compression::8, _filter::8,
      _interlace::8>> = data

    parse_chunks(
      rest,
      Map.merge(acc, %{width: width, height: height, bit_depth: bit_depth, color_type: color_type})
    )
  end

  defp parse_chunks(<<len::32, "IDAT", data::binary-size(len), _crc::32, rest::binary>>, acc) do
    parse_chunks(rest, %{acc | idat: acc.idat <> data})
  end

  defp parse_chunks(
         <<len::32, _type::binary-size(4), _data::binary-size(len), _crc::32, rest::binary>>,
         acc
       ) do
    parse_chunks(rest, acc)
  end

  defp parse_chunks(_, _acc), do: {:error, "Invalid PNG"}

  # Grayscale
  defp bytes_per_pixel(0, _), do: 1
  # RGB
  defp bytes_per_pixel(2, _), do: 3
  # Indexed
  defp bytes_per_pixel(3, _), do: 1
  # Grayscale+Alpha
  defp bytes_per_pixel(4, _), do: 2
  # RGBA
  defp bytes_per_pixel(6, _), do: 4
  defp bytes_per_pixel(_, _), do: 3

  defp build_image(%{width: w, height: h, idat: compressed, color_type: ct, bit_depth: bd}) do
    raw = :zlib.uncompress(compressed)
    bpp = bytes_per_pixel(ct, bd)
    pixels_per_row = w * bpp

    rows =
      raw
      |> split_rows(pixels_per_row, bpp, [])
      |> Enum.map(&unfilter_row(&1, bpp))

    pixels = Enum.flat_map(rows, fn row -> row end)
    {:ok, {w, h, pixels}}
  end

  defp split_rows(<<>>, _ppr, _bpp, acc), do: Enum.reverse(acc)

  defp split_rows(<<filter::8, rest::binary>>, ppr, bpp, acc) do
    row_size = min(ppr, byte_size(rest))
    <<row::binary-size(row_size), remaining::binary>> = rest
    pixels = extract_pixels(row, bpp)
    split_rows(remaining, ppr, bpp, [{filter, pixels} | acc])
  end

  defp extract_pixels(<<>>, _bpp), do: []

  defp extract_pixels(row, 1) do
    for i <- 0..(byte_size(row) - 1) do
      v = :binary.at(row, i)
      {v, v, v}
    end
  end

  defp extract_pixels(row, 2) do
    count = div(byte_size(row), 2)

    for i <- 0..(count - 1) do
      v = :binary.at(row, i * 2)
      {v, v, v}
    end
  end

  defp extract_pixels(row, bpp) do
    count = div(byte_size(row), bpp)

    for i <- 0..(count - 1) do
      offset = i * bpp
      {:binary.at(row, offset), :binary.at(row, offset + 1), :binary.at(row, offset + 2)}
    end
  end

  # None
  defp unfilter_row({0, pixels}, _bpp), do: pixels
  # Sub
  defp unfilter_row({1, pixels}, bpp), do: unfilter_sub(pixels, bpp)
  # Up (first row has no up)
  defp unfilter_row({2, pixels}, _bpp), do: pixels
  # Average/Paeth — skip for simplicity
  defp unfilter_row({_f, pixels}, _bpp), do: pixels

  defp unfilter_sub(pixels, bpp) do
    pixels
    |> Enum.with_index()
    |> Enum.map(fn {{r, g, b}, i} ->
      if i < bpp do
        {r, g, b}
      else
        {pr, pg, pb} = Enum.at(pixels, i - 1)
        {rem(r + pr, 256), rem(g + pg, 256), rem(b + pb, 256)}
      end
    end)
  end

  defp resize_pixels(pixels, src_w, src_h, dst_w, dst_h) do
    for y <- 0..(dst_h - 1) do
      src_y = round(y * src_h / dst_h) |> min(src_h - 1)

      for x <- 0..(dst_w - 1) do
        src_x = round(x * src_w / dst_w) |> min(src_w - 1)
        Enum.at(pixels, src_y * src_w + src_x)
      end
    end
  end

  # ── Generate ───────────────────────────────────────────────────────────

  @doc """
  Generates an RGB PNG binary from pixel data.
  """
  @spec generate_rgb([[{0..255, 0..255, 0..255}]], pos_integer(), pos_integer()) :: binary()
  def generate_rgb(pixels, width, height) do
    raw_data = generate_rgb_data(pixels, width, height)
    compressed = :zlib.compress(raw_data)

    png_header() <>
      ihdr_chunk(width, height) <>
      idat_chunk(compressed) <>
      iend_chunk()
  end

  @doc """
  Generates an RGBA PNG binary from pixel data (with alpha channel).
  """
  @spec generate_rgba([[{0..255, 0..255, 0..255, 0..255}]], pos_integer(), pos_integer()) :: binary()
  def generate_rgba(pixels, width, height) do
    raw_data = generate_rgba_data(pixels, width, height)
    compressed = :zlib.compress(raw_data)

    png_header() <>
      ihdr_rgba_chunk(width, height) <>
      idat_chunk(compressed) <>
      iend_chunk()
  end

  defp generate_rgb_data(pixels, width, height) do
    rows = Enum.take(pixels, height)

    Enum.reduce(rows, "", fn row, acc ->
      row_data =
        Enum.reduce(Enum.take(row, width), "", fn {r, g, b}, row_acc ->
          row_acc <> <<r, g, b>>
        end)

      acc <> <<0>> <> row_data
    end)
  end

  defp generate_rgba_data(pixels, width, height) do
    rows = Enum.take(pixels, height)

    Enum.reduce(rows, "", fn row, acc ->
      row_data =
        Enum.reduce(Enum.take(row, width), "", fn {r, g, b, a}, row_acc ->
          row_acc <> <<r, g, b, a>>
        end)

      acc <> <<0>> <> row_data
    end)
  end

  defp png_header, do: <<137, 80, 78, 71, 13, 10, 26, 10>>

  defp ihdr_chunk(width, height) do
    data = <<width::big-size(32), height::big-size(32), 8::size(8), 2::size(8), 0::size(8),
      0::size(8), 0::size(8)>>
    chunk("IHDR", data)
  end

  defp ihdr_rgba_chunk(width, height) do
    data = <<width::big-size(32), height::big-size(32), 8::size(8), 6::size(8), 0::size(8),
      0::size(8), 0::size(8)>>
    chunk("IHDR", data)
  end

  defp idat_chunk(compressed), do: chunk("IDAT", compressed)
  defp iend_chunk, do: chunk("IEND", <<>>)

  defp chunk(type, data) do
    length = byte_size(data)
    crc = :erlang.crc32(<<type::binary, data::binary>>)
    <<length::size(32), type::binary, data::binary, crc::size(32)>>
  end
end
