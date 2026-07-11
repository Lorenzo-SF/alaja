defmodule Alaja.ImageRenderer do
  @moduledoc """
  Image rendering for terminal emulators.

  Supports multiple protocols:
  - Kitty Graphics Protocol
  - iTerm2 Inline Images
  - Sixel (via img2sixel)
  - ASCII fallback (via img2txt)
  - ASCII art (coloured or monochrome, pure Elixir for PNG)

  ## Usage

      # Render an image file
      Alaja.ImageRenderer.render_file("image.png")

      # Render pixel data directly
      pixels = for y <- 0..99, do: for x <- 0..99, do: {x * 2, y * 2, 128}
      Alaja.ImageRenderer.render(pixels, width: 100, height: 100)

      # Detect protocol
      protocol = Alaja.ImageRenderer.detect_protocol()
  """

  alias Alaja.ImageRenderer.PNG, as: PNG
  alias Alaja.ImageTerminal, as: Terminal
  alias Alaja.Terminal, as: ScreenTerminal

  @doc """
  Renders an image file to the terminal.

  ## Options
    - `:width` — Target width in cells
    - `:height` — Target height in cells
    - `:protocol` — Force a specific protocol (`:kitty`, `:iterm2`, `:sixel`, `:ascii`)
  """
  @spec render_file(String.t(), keyword()) :: :ok | :unsupported | {:error, term()}
  def render_file(path, opts \\ []) do
    if File.exists?(path) do
      protocol = Keyword.get(opts, :protocol) || Terminal.image_protocol()
      width = Keyword.get(opts, :width, 40)
      height = Keyword.get(opts, :height, 20)
      align = Keyword.get(opts, :align, :left)
      terminal_width = ScreenTerminal.size() |> elem(0)
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
    - `pixels` — List of rows, each row is a list of `{r, g, b}` tuples
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

  @doc """
  Detects the best protocol for the current terminal.
  """
  @spec detect_protocol() :: :kitty | :iterm2 | :sixel | :ascii
  def detect_protocol, do: Terminal.image_protocol()

  # ── Alignment ───────────────────────────────────────────────────────────

  defp calculate_alignment_padding(:left, _terminal_width, _image_width), do: 0

  defp calculate_alignment_padding(:center, terminal_width, image_width) do
    max(0, div(terminal_width - image_width, 2))
  end

  defp calculate_alignment_padding(:right, terminal_width, image_width) do
    max(0, terminal_width - image_width)
  end

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
    png_data = PNG.generate_rgb(pixels, width, height)
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
        IO.write(String.duplicate(" ", padding))
        IO.write("\e]1337;File=inline=1;width=#{width}:#{b64}\a")
        IO.write("\n")
        :ok

      _ ->
        :unsupported
    end
  end

  defp render_iterm2_pixels(pixels, width, height, padding) do
    png_data = PNG.generate_rgb(pixels, width, height)
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
    case trebejo_call(:render_sixel, [path, width, height]) do
      {:ok, output} ->
        IO.write(String.duplicate(" ", padding))
        IO.write(output)
        IO.write("\n")
        :ok

      :tool_not_found ->
        render_ascii_file(path, width, padding)

      {:error, _reason} ->
        :unsupported
    end
  end

  # ============================================================================
  # ASCII Fallback
  # ============================================================================

  defp render_ascii_file(path, width, padding) do
    case trebejo_call(:image_to_ascii, [path, width]) do
      {:ok, output} ->
        IO.write(String.duplicate(" ", padding))
        IO.write(output)
        IO.write("\n")
        :ok

      _ ->
        :unsupported
    end
  end

  # ============================================================================
  # ASCII Art — colored or monochrome, using pure Elixir PNG decoder
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

  - `:width` — target width in characters
  - `:height` — target height in characters
  - `:ascii_style` — character set preset
  - `:ascii_chars` — custom character string
  - `:ascii_color` — whether to colorize output (default: true)
  - `:ascii_saturation` — color saturation 0.0-1.0
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

  @doc """
  Loads image pixels for rendering.

  Returns pixel data as a list of rows, each row a list of `{r, g, b}` tuples.
  Supports PNG natively; other formats require ImageMagick's `convert`.
  """
  @spec load_image_pixels(String.t(), keyword()) ::
          {:ok, [[{0..255, 0..255, 0..255}]]} | {:error, String.t()}
  def load_image_pixels(path, opts \\ []) do
    width = Keyword.get(opts, :width, 40)
    height = Keyword.get(opts, :height, 0)
    read_image_pixels(path, width, height)
  end

  defp read_image_pixels(path, target_w, target_h) do
    case PNG.decode(path) do
      {:ok, {src_w, src_h, pixels}} ->
        aspect = src_h / src_w
        th = if target_h > 0, do: target_h, else: max(1, round(target_w * aspect / 2.0))
        resized = resize_pixels(pixels, src_w, src_h, target_w, th)
        {:ok, resized}

      :not_png ->
        try_convert_fallback(path, target_w, target_h)

      {:error, _} = e ->
        e
    end
  end

  defp try_convert_fallback(path, target_w, target_h) do
    case trebejo_call(:convert_to_png, [path, target_w, target_h]) do
      {:ok, tmp} ->
        result = read_image_pixels(tmp, target_w, target_h)
        File.rm(tmp)
        result

      :tool_not_found ->
        {:error, "Only PNG supported natively. Install ImageMagick for other formats."}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── ASCII art builder ──────────────────────────────────────────────────

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

  # ── Backward-compatible re-exports (delegated to PNG submodule) ────────

  @doc "Generates an RGB PNG binary from pixel data."
  @spec generate_png([[{0..255, 0..255, 0..255}]], pos_integer(), pos_integer()) :: binary()
  defdelegate generate_png(pixels, width, height), to: PNG, as: :generate_rgb

  @doc "Generates an RGBA PNG binary from pixel data (with alpha)."
  @spec generate_png_rgba(
          [[{0..255, 0..255, 0..255, 0..255}]],
          pos_integer(),
          pos_integer()
        ) :: binary()
  defdelegate generate_png_rgba(pixels, width, height), to: PNG, as: :generate_rgba

  # ── Utility ────────────────────────────────────────────────────────────

  defp resize_pixels(pixels, src_w, src_h, dst_w, dst_h) do
    for y <- 0..(dst_h - 1) do
      src_y = round(y * src_h / dst_h) |> min(src_h - 1)

      for x <- 0..(dst_w - 1) do
        src_x = round(x * src_w / dst_w) |> min(src_w - 1)
        Enum.at(pixels, src_y * src_w + src_x)
      end
    end
  end

  defp chunk_string(string, size) do
    string
    |> String.graphemes()
    |> Enum.chunk_every(size)
    |> Enum.map(&Enum.join/1)
  end

  # ── Runtime dispatch to Trebejo.Image (optional dependency) ───────────

  defp trebejo_call(func, args) do
    if Code.ensure_loaded?(Trebejo.Image) do
      apply(Trebejo.Image, func, args)
    else
      :tool_not_found
    end
  end
end
