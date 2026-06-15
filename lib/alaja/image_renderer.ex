defmodule Alaja.ImageRenderer do
  @moduledoc """
  Image rendering for terminal emulators.

  Supports multiple protocols:
  - Kitty Graphics Protocol
  - iTerm2 Inline Images
  - Sixel (via img2sixel)
  - ASCII fallback

  ## Usage

      # Render an image file
      Alaja.ImageRenderer.render_file("image.png")

      # Render pixel data directly
      pixels = for y <- 0..99, do: for x <- 0..99, do: {x * 2, y * 2, 128}
      Alaja.ImageRenderer.render(pixels, width: 100, height: 100)

      # Detect protocol
      protocol = Alaja.ImageRenderer.detect_protocol()

  """

  alias Alaja.ImageTerminal, as: Terminal
  alias Alaja.Terminal, as: ScreenTerminal

  @doc """
  Renders an image file to the terminal.

  ## Options
    - `:width` - Target width in cells
    - `:height` - Target height in cells
    - `:protocol` - Force a specific protocol (`:kitty`, `:iterm2`, `:sixel`, `:ascii`)
  """
  @spec render_file(String.t(), keyword()) :: :ok | :unsupported
  def render_file(path, opts \\ []) do
    if File.exists?(path) do
      protocol = Keyword.get(opts, :protocol) || Terminal.image_protocol()
      width = Keyword.get(opts, :width, 40)
      height = Keyword.get(opts, :height, 20)
      align = Keyword.get(opts, :align, :left)

      # Get terminal width for alignment calculation
      terminal_width = ScreenTerminal.size() |> elem(0)

      # Calculate alignment padding
      padding = calculate_alignment_padding(align, terminal_width, width)

      case protocol do
        :kitty -> render_kitty_file(path, width, height, padding)
        :iterm2 -> render_iterm2_file(path, width, padding)
        :sixel -> render_sixel_file(path, width, height, padding)
        :ascii -> render_ascii_file(path, width, padding)
        _ -> :unsupported
      end
    else
      {:error, :file_not_found}
    end
  end

  @doc """
  Renders pixel data to the terminal.

  ## Parameters
    - `pixels` - List of rows, each row is a list of `{r, g, b}` tuples
  """
  @spec render([[{non_neg_integer(), non_neg_integer(), non_neg_integer()}]], keyword()) ::
          :ok | :unsupported
  def render(pixels, opts \\ []) do
    protocol = Keyword.get(opts, :protocol) || Terminal.image_protocol()
    width = Keyword.get(opts, :width, length(List.first(pixels, [])))
    height = Keyword.get(opts, :height, length(pixels))
    align = Keyword.get(opts, :align, :left)
    terminal_width = ScreenTerminal.size() |> elem(0)
    padding = calculate_alignment_padding(align, terminal_width, width)

    case protocol do
      :kitty -> render_kitty_pixels(pixels, width, height, padding)
      :iterm2 -> render_iterm2_pixels(pixels, width, height, padding)
      :sixel -> :unsupported
      :ascii -> :unsupported
      _ -> :unsupported
    end
  end

  # Calculate left padding for alignment
  defp calculate_alignment_padding(:left, _terminal_width, _image_width), do: 0

  defp calculate_alignment_padding(:center, terminal_width, image_width) do
    max(0, div(terminal_width - image_width, 2))
  end

  defp calculate_alignment_padding(:right, terminal_width, image_width) do
    max(0, terminal_width - image_width)
  end

  @doc """
  Detects the best protocol for the current terminal.
  """
  @spec detect_protocol() :: :kitty | :iterm2 | :sixel | :ascii
  def detect_protocol, do: Terminal.image_protocol()

  # ============================================================================
  # Kitty Protocol
  # ============================================================================

  defp render_kitty_file(path, width, height, padding) do
    case File.read(path) do
      {:ok, bin} ->
        b64 = Base.encode64(bin)
        chunks = chunk_string(b64, 4096)
        last_idx = length(chunks) - 1

        IO.write(String.duplicate(" ", padding))
        write_kitty_chunks(chunks, 1, width, height, last_idx, true)
        IO.write("\n")
        :ok

      _ ->
        :unsupported
    end
  end

  defp render_kitty_pixels(pixels, width, height, padding) do
    png_data = generate_png(pixels, width, height)
    b64 = Base.encode64(png_data)
    chunks = chunk_string(b64, 4096)
    last_idx = length(chunks) - 1

    IO.write(String.duplicate(" ", padding))
    write_kitty_chunks(chunks, 1, width, height, last_idx, true)
    IO.write("\n")
    :ok
  end

  defp write_kitty_chunks(chunks, id, cols, rows, last_idx, is_transmission) do
    chunks
    |> Enum.with_index()
    |> Enum.each(fn {chunk, idx} ->
      write_kitty_chunk(chunk, idx, id, cols, rows, last_idx, is_transmission)
    end)
  end

  @dialyzer {:nowarn_function, {:write_kitty_chunk, 7}}
  defp write_kitty_chunk(chunk, idx, id, cols, rows, last_idx, is_transmission) do
    more = if idx < last_idx, do: 1, else: 0
    base = if is_transmission, do: "T", else: "t"

    if idx == 0 do
      opts = if is_transmission, do: "c=#{cols},r=#{rows},", else: ""
      IO.write("\e_Gf=100,a=#{base},i=#{id},q=2,#{opts}m=#{more};#{chunk}\e\\")
    else
      IO.write("\e_Gm=#{more};#{chunk}\e\\")
    end
  end

  # ============================================================================
  # iTerm2 Protocol
  # ============================================================================

  defp render_iterm2_file(path, width, padding) do
    case File.read(path) do
      {:ok, bin} ->
        b64 = Base.encode64(bin)
        # iTerm2 inline images: padding spaces before, then image, then newline
        IO.write(String.duplicate(" ", padding))
        IO.write("\e]1337;File=inline=1;width=#{width}:#{b64}\a")
        IO.write("\n")
        :ok

      _ ->
        :unsupported
    end
  end

  defp render_iterm2_pixels(pixels, width, height, padding) do
    png_data = generate_png(pixels, width, height)
    b64 = Base.encode64(png_data)

    IO.write(String.duplicate(" ", padding))
    IO.write("\e]1337;File=inline=1;width=#{width}:#{b64}\a")
    IO.write("\n")
    :ok
  end

  # ============================================================================
  # Sixel Protocol
  # ============================================================================

  defp render_sixel_file(path, width, height, padding) do
    if System.find_executable("img2sixel") do
      {output, exit_code} =
        System.cmd("img2sixel", ["-w", to_string(width), "-h", to_string(height), path],
          stderr_to_stdout: true
        )

      if exit_code == 0 do
        IO.write(String.duplicate(" ", padding))
        IO.write(output)
        IO.write("\n")
        :ok
      else
        :unsupported
      end
    else
      render_ascii_file(path, width, padding)
    end
  end

  # ============================================================================
  # ASCII Fallback
  # ============================================================================

  defp render_ascii_file(path, width, padding) do
    if System.find_executable("img2txt") do
      {output, exit_code} =
        System.cmd("img2txt", ["-W", to_string(width), path], stderr_to_stdout: true)

      if exit_code == 0 do
        IO.write(String.duplicate(" ", padding))
        IO.write(output)
        IO.write("\n")
        :ok
      else
        :unsupported
      end
    else
      :unsupported
    end
  end

  # ============================================================================
  # ASCII Art — colored or monochrome, using Python3 + PIL for pixel sampling
  # ============================================================================

  @ascii_styles %{
    blocks: " ░▒▓█",
    detailed: " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$",
    simple: " .:-=+*#%@",
    braille: " ⠁⠂⠄⠈⠐⠠⢀⣀⣠⣤⣦⣶⣷⣿"
  }

  @doc """
  Renders an image as colored or monochrome ASCII art.

  Only PNG is supported natively (pure Elixir). For other formats,
  ImageMagick (`convert`) is required as a fallback.

  ## Options

  - `:width` — target width in characters (default: 40)
  - `:height` — target height in characters (default: auto from aspect ratio)
  - `:ascii_style` — character set preset (`:blocks`, `:detailed`, `:simple`, `:braille`)
  - `:ascii_chars` — custom character string (overrides `:ascii_style`)
  - `:ascii_color` — whether to colorize output (default: true)
  - `:ascii_saturation` — color saturation 0.0-1.0 (default: 1.0)
  """
  @spec render_ascii_art(String.t(), keyword()) :: :ok | :unsupported
  def render_ascii_art(path, opts \\ []) do
    width = Keyword.get(opts, :width, 40)
    height = Keyword.get(opts, :height, 0)
    color = Keyword.get(opts, :ascii_color, true)
    saturation = Keyword.get(opts, :ascii_saturation, 1.0) |> max(0.0) |> min(1.0)

    chars =
      Keyword.get(opts, :ascii_chars) || @ascii_styles[Keyword.get(opts, :ascii_style, :blocks)]

    case read_image_pixels(path, width, height) do
      {:ok, pixels} ->
        output_lines = build_ascii_art(pixels, chars, color, saturation)
        IO.write(output_lines)
        IO.write("\n")
        :ok

      {:error, reason} ->
        IO.puts(:stderr, "ASCII art error: #{reason}")
        :unsupported
    end
  end

  # ---------------------------------------------------------------------------
  # PNG decoder (pure Elixir)
  # ---------------------------------------------------------------------------

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  @doc """
  Loads image pixels for rendering.

  Returns pixel data as a list of rows, each row a list of {r, g, b} tuples.
  Supports PNG natively; other formats require ImageMagick's `convert`.

  ## Options
    - `:width` — target width in characters (default: 40)
    - `:height` — target height in characters (default: auto from aspect ratio)
  """
  @spec load_image_pixels(String.t(), keyword()) :: {:ok, [[{0..255, 0..255, 0..255}]]} | {:error, String.t()}
  def load_image_pixels(path, opts \\ []) do
    width = Keyword.get(opts, :width, 40)
    height = Keyword.get(opts, :height, 0)
    read_image_pixels(path, width, height)
  end

  defp read_image_pixels(path, target_w, target_h) do
    with {:ok, bin} <- File.read(path),
         :png <- detect_format(bin),
         {:ok, {src_w, src_h, pixels}} <- decode_png(bin) do
      aspect = src_h / src_w
      th = if target_h > 0, do: target_h, else: max(1, round(target_w * aspect / 2.0))
      resized = resize_pixels(pixels, src_w, src_h, target_w, th)
      {:ok, resized}
    else
      {:error, _} = e -> e
      :not_png -> try_convert_fallback(path, target_w, target_h)
    end
  end

  defp detect_format(<<@png_signature, _::binary>>), do: :png
  defp detect_format(_), do: :not_png

  defp try_convert_fallback(path, target_w, target_h) do
    if System.find_executable("convert") do
      tmp = Path.expand("/tmp/alaja_ascii_#{:erlang.unique_integer([:positive])}.png")
      cmd = ["convert", path, "-resize", "#{target_w}x#{target_h}>", tmp]

      case System.cmd(hd(cmd), tl(cmd), stderr_to_stdout: true) do
        {_, 0} ->
          result = read_image_pixels(tmp, target_w, target_h)
          File.rm(tmp)
          result

        {err, _} ->
          {:error, "convert failed: #{String.slice(err, 0, 200)}"}
      end
    else
      {:error, "Only PNG supported natively. Install ImageMagick for other formats."}
    end
  end

  defp decode_png(bin) do
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

  defp build_ascii_art(pixels, chars, color, saturation) do
    max_idx = max(String.length(chars) - 1, 1)

    Enum.map_join(pixels, "\n", fn row ->
      Enum.map_join(row, &render_pixel(&1, chars, color, saturation, max_idx))
    end)
  end

  defp render_pixel({r, g, b}, chars, color, saturation, max_idx) do
    brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
    idx = round(brightness * max_idx) |> max(0) |> min(max_idx)
    char = String.at(chars, idx)

    if color do
      gray = round(r * 0.299 + g * 0.587 + b * 0.114)
      sr = round(r * saturation + gray * (1.0 - saturation))
      sg = round(g * saturation + gray * (1.0 - saturation))
      sb = round(b * saturation + gray * (1.0 - saturation))
      "#{Pote.Orchestrator.to_ansi({sr, sg, sb})}#{char}#{Alaja.ANSI.reset_attributes()}"
    else
      char
    end
  end

  # ============================================================================
  # PNG Generation (minimal)
  # ============================================================================

  @doc """
  Generates a PNG binary from pixel data.

  ## Parameters

    - `pixels` - List of rows, each row a list of `{r, g, b}` tuples
    - `width` - Image width in pixels
    - `height` - Image height in pixels
  """
  @spec generate_png(
          [[{non_neg_integer(), non_neg_integer(), non_neg_integer()}]],
          pos_integer(),
          pos_integer()
        ) :: binary()
  def generate_png(pixels, width, height) do
    raw_data = generate_rgb_data(pixels, width, height)
    compressed = :zlib.compress(raw_data)

    png_header() <>
      ihdr_chunk(width, height) <>
      idat_chunk(compressed) <>
      iend_chunk()
  end

  @doc """
  Generates a PNG binary from RGBA pixel data (with alpha channel for transparency).

  ## Parameters

    - `pixels` - List of rows, each row a list of `{r, g, b, a}` tuples
    - `width` - Image width in pixels
    - `height` - Image height in pixels
  """
  @spec generate_png_rgba(
          [[{non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}]],
          pos_integer(),
          pos_integer()
        ) :: binary()
  def generate_png_rgba(pixels, width, height) do
    raw_data = generate_rgba_data(pixels, width, height)
    compressed = :zlib.compress(raw_data)

    png_header() <>
      ihdr_rgba_chunk(width, height) <>
      idat_chunk(compressed) <>
      iend_chunk()
  end

  defp generate_rgb_data(pixels, width, height) do
    # Create raw image data with filter byte (0) at start of each row
    rows = Enum.take(pixels, height)

    Enum.reduce(rows, "", fn row, acc ->
      row_data =
        Enum.reduce(Enum.take(row, width), "", fn {r, g, b}, row_acc ->
          row_acc <> <<r, g, b>>
        end)

      # 0 = no filter
      acc <> <<0>> <> row_data
    end)
  end

  defp generate_rgba_data(pixels, width, height) do
    # Create raw RGBA image data with filter byte (0) at start of each row
    rows = Enum.take(pixels, height)

    Enum.reduce(rows, "", fn row, acc ->
      row_data =
        Enum.reduce(Enum.take(row, width), "", fn {r, g, b, a}, row_acc ->
          row_acc <> <<r, g, b, a>>
        end)

      # 0 = no filter
      acc <> <<0>> <> row_data
    end)
  end

  defp png_header, do: <<137, 80, 78, 71, 13, 10, 26, 10>>

  defp ihdr_chunk(width, height) do
    data = <<
      # width (big-endian)
      width::big-size(32),
      # height (big-endian)
      height::big-size(32),
      # bit depth
      8::size(8),
      # color type (RGB)
      2::size(8),
      # compression
      0::size(8),
      # filter
      0::size(8),
      # interlace
      0::size(8)
    >>

    chunk("IHDR", data)
  end

  defp ihdr_rgba_chunk(width, height) do
    data = <<
      # width (big-endian)
      width::big-size(32),
      # height (big-endian)
      height::big-size(32),
      # bit depth
      8::size(8),
      # color type (RGBA)
      6::size(8),
      # compression
      0::size(8),
      # filter
      0::size(8),
      # interlace
      0::size(8)
    >>

    chunk("IHDR", data)
  end

  defp idat_chunk(compressed) do
    chunk("IDAT", compressed)
  end

  defp iend_chunk do
    chunk("IEND", <<>>)
  end

  defp chunk(type, data) do
    length = byte_size(data)
    crc = :erlang.crc32(<<type::binary, data::binary>>)
    <<length::size(32), type::binary, data::binary, crc::size(32)>>
  end

  defp chunk_string(string, size) do
    string
    |> String.graphemes()
    |> Enum.chunk_every(size)
    |> Enum.map(&Enum.join/1)
  end
end
