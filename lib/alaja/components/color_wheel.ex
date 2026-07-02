defmodule Alaja.Components.ColorWheel do
  alias Alaja.{Buffer, Cell}
  alias Alaja.ImageRenderer
  alias Alaja.ImageTerminal, as: Terminal

  @moduledoc """
  Color visualization component for the terminal.

  Provides multiple rendering modes:

  - **Native image** (Kitty/iTerm2/Sixel): generates a real bitmap of the color
    wheel using the detected terminal protocol, with the harmony colours
    marked at their hue position.
  - **ASCII half-block** (universal fallback): renders a circle using Unicode
    `▀`/`▄` characters with true-color ANSI (24-bit), yielding 2 pixels per
    vertical cell. This is the Buffer-first canonical rendering.

  The canonical entry point is `render/2`, which returns an
  `Alaja.Buffer.t/0`. Callers that want native-image output should
  use `render_for_terminal/2` (returns a tagged value so the caller
  decides whether to embed the bytes directly or feed a Buffer to
  the printer).

  ## Contracts

  Este módulo usa los tipos definidos en `Pote` como fuente canónica.

  ## Examples

      alias Alaja.Components.ColorWheel

      # Canonical Buffer-first render (works in any terminal)
      buffer = ColorWheel.render([{255, 0, 0}, {0, 255, 0}], harmony: :triad)
      Alaja.Printer.print_raw(buffer)

      # Native image when supported, ASCII fallback otherwise
      case ColorWheel.render_for_terminal([{255, 0, 0}], harmony: :triad) do
        {:image, iodata} -> IO.write(iodata)
        {:ascii, buffer} -> Alaja.Printer.print_raw(buffer)
      end

      # Legacy IO-based helpers (deprecated but still work)
      ColorWheel.show_color_info({255, 87, 51})
      ColorWheel.show_harmony_ring({255, 0, 0}, :triad)
      ColorWheel.show_swatches([{255, 0, 0}, {0, 255, 0}, {0, 0, 255}])

  """

  alias Pote
  alias Pote.{Converters, Harmonies, Orchestrator}

  @type rgb :: Pote.rgb()

  @ascii_radius 10

  # ═══════════════════════════════════════════════════════════════════════════
  # CANONICAL BUFFER-FIRST API
  # ═════════════════════════════════════════════════════════════════════════

  @doc """
  Canonical Buffer-first render entry point.

  Returns an `Alaja.Buffer.t/0` containing the colour wheel drawn with
  Unicode half-block characters (▀/▄) at the requested harmony colours'
  hue positions. The buffer is sized `4*radius+1` cells wide by `radius`
  cells tall, where the x-scale of 2.0 makes the wheel appear circular
  on terminals whose cells are taller than wide.

  ## Options

    - `:radius` — wheel radius in cells (default: 10)
    - `:thickness` — ring thickness as a fraction of the radius (default: 0.4)
    - `:harmony` — atom for the harmony type, draws the marker label in
                   the centre (`:triad`, `:complementary`, etc.)
    - `:harmony_angles` — explicit list of hue angles to mark (overrides
                          `:harmony` for the marker positions)

  When `:harmony` is set, a centred label is embedded in the centre row
  using a white-on-black pill. When `:harmony_angles` is set, no label is
  drawn (the wheel is "unlabelled").
  """
  @spec render([rgb()], keyword()) :: Buffer.t()
  def render(rgb_list, opts \\ []) do
    harmony_angles = render_angles_for(rgb_list, opts)
    render_wheel_buffer(harmony_angles, opts)
  end

  @doc """
  Render the wheel using the best protocol for the current terminal.

  Returns:
    * `{:image, iodata}` — when the terminal supports native images
      (Kitty, iTerm2, Sixel); `iodata` contains the terminal escape codes
      for an inline PNG with the wheel and harmony markers.
    * `{:ascii, Buffer.t()}` — otherwise; the Buffer can be passed to
      `Alaja.Printer.print_raw/2`.

  The caller dispatches on the tag because PNG escapes cannot be embedded
  in a Buffer cell — they have to be written directly to stdout by the
  caller.
  """
  @spec render_for_terminal([rgb()], keyword()) ::
          {:image, iodata()} | {:ascii, Buffer.t()}
  def render_for_terminal(rgb_list, opts \\ []) do
    if Terminal.supports_images?() do
      {:image, render_png_wheel(rgb_list, opts)}
    else
      {:ascii, render(rgb_list, opts)}
    end
  end

  @doc """
  Returns the default options for the wheel renderer.
  """
  @spec default_opts() :: keyword()
  def default_opts do
    [radius: @ascii_radius, thickness: 0.4]
  end

  # Internal: build the Buffer with the colour wheel and optional harmony markers.
  defp render_wheel_buffer(harmony_angles, opts) do
    radius = Keyword.get(opts, :radius, @ascii_radius)
    thickness = Keyword.get(opts, :thickness, 0.4)
    x_scale = 2.0
    harmony_type = Keyword.get(opts, :harmony)

    harmony_label =
      if harmony_type, do: harmony_display_name(harmony_type), else: nil

    width = round(radius * x_scale) - round(-radius * x_scale) + 1
    height = radius
    x_offset = -round(-radius * x_scale)

    buffer = Buffer.new(width, height)

    buffer =
      Enum.reduce(0..(height - 1), buffer, fn y_pair, buf ->
        y_top = y_pair * 2 - radius
        y_bot = y_top + 1

        Enum.reduce(round(-radius * x_scale)..round(radius * x_scale), buf, fn x_cell, b ->
          x = x_cell / x_scale
          top_color = pixel_color_at(x, y_top, radius, harmony_angles, thickness)
          bot_color = pixel_color_at(x, y_bot, radius, harmony_angles, thickness)
          cell = half_block_cell(top_color, bot_color)
          Buffer.update_cell(b, x_cell + x_offset, y_pair, cell)
        end)
      end)

    maybe_annotate_label(buffer, harmony_label)
  end

  # If a harmony label is provided, draw a centred white-on-black pill on
  # the centre row. Returns the buffer unchanged when there's no label.
  defp maybe_annotate_label(buffer, nil), do: buffer

  defp maybe_annotate_label(buffer, label) do
    label_text = " #{label} "
    label_len = String.length(label_text)
    width = buffer.width
    height = buffer.height
    center_y = div(height, 2)

    if label_len + 2 < width do
      start_x = div(width - label_len, 2)

      label_text
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.reduce(buffer, fn {char, idx}, buf ->
        Buffer.put(buf, start_x + idx, center_y, char, {255, 255, 255}, {0, 0, 0})
      end)
    else
      buffer
    end
  end

  # Build the Cell for one half-block position.
  # `top_color` and `bot_color` are `{r,g,b}` tuples or `nil` for empty.
  defp half_block_cell(nil, nil), do: Cell.empty()
  defp half_block_cell({r, g, b}, nil), do: Cell.new("▀", {r, g, b})
  defp half_block_cell(nil, {r, g, b}), do: Cell.new("▄", {r, g, b})
  defp half_block_cell({tr, tg, tb}, {br, bg, bb}), do: Cell.new("▀", {tr, tg, tb}, {br, bg, bb})

  defp render_angles_for(rgb_list, opts) do
    case Keyword.fetch(opts, :harmony_angles) do
      {:ok, angles} when is_list(angles) ->
        angles

      _ ->
        # Default: extract angles from the rgb_list. The caller can pass
        # either pre-computed angles or a list of RGBs.
        extract_angles(rgb_list)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Displays detailed color information: swatch, formats, and optional variants.
  """
  @spec show_color_info(Orchestrator.color_input(), keyword()) :: :ok
  def show_color_info(color, opts \\ []) do
    show_formats = Keyword.get(opts, :show_formats, true)
    show_variants = Keyword.get(opts, :show_variants, false)

    rgb = resolve_rgb(color)
    {r, g, b} = rgb

    IO.puts(
      "#{Pote.Orchestrator.to_ansi({r, g, b})}  ████████████████████#{Alaja.ANSI.reset_attributes()}"
    )

    IO.puts("")

    if show_formats, do: render_color_formats(rgb)
    if show_variants, do: render_color_variants(rgb)

    :ok
  end

  @doc """
  Shows a harmony ring using ASCII rendering with autodetection of terminal
  capabilities. Falls back to ASCII half-block when the terminal does not
  support native image protocols.
  """
  @spec show_harmony_ring(Orchestrator.color_input(), atom(), keyword()) :: :ok
  def show_harmony_ring(base_color, harmony_type \\ :triad, opts \\ []) do
    base_rgb = resolve_rgb(base_color)
    colors = compute_harmony(base_rgb, harmony_type)
    harmony_name = harmony_display_name(harmony_type)

    IO.puts("  #{Alaja.ANSI.bold_on()}🎨 #{harmony_name}#{Alaja.ANSI.reset_attributes()}\n")

    angles = extract_angles([base_rgb | colors])
    render_ascii_wheel(angles, harmony_type, opts)

    IO.puts("")
    render_swatch_list([base_rgb | colors])
    :ok
  end

  @doc """
  Shows a list of colors as linear swatches.
  """
  @spec show_swatches([Orchestrator.color_input()], keyword()) :: :ok
  def show_swatches(colors, opts \\ []) do
    per_row = Keyword.get(opts, :per_row, 4)

    colors
    |> Enum.map(&resolve_rgb/1)
    |> Enum.chunk_every(per_row)
    |> Enum.each(fn chunk ->
      line =
        Enum.map_join(chunk, "  ", fn {r, g, b} ->
          hex = Converters.rgb_to_hex({r, g, b})
          "#{Pote.Orchestrator.to_ansi({r, g, b})}████████#{Alaja.ANSI.reset_attributes()} #{hex}"
        end)

      IO.puts("  #{line}")
    end)

    :ok
  end

  @doc """
  Shows a horizontal gradient between two colors.
  """
  @spec show_gradient(Orchestrator.color_input(), Orchestrator.color_input(), pos_integer()) ::
          :ok
  def show_gradient(start_color, end_color, steps \\ 20) do
    start_rgb = resolve_rgb(start_color)
    end_rgb = resolve_rgb(end_color)

    gradient =
      Enum.map_join(0..(steps - 1), fn i ->
        factor = i / max(steps - 1, 1)
        {r, g, b} = blend(start_rgb, end_rgb, factor)
        "#{Pote.Orchestrator.to_ansi({r, g, b})}██#{Alaja.ANSI.reset_attributes()}"
      end)

    IO.puts("  #{gradient}")
    :ok
  end

  @doc """
  Renders the ASCII color wheel and returns the lines (for layout composition).
  """
  @spec get_ascii_wheel_lines([number()], atom(), keyword()) :: [String.t()]
  def get_ascii_wheel_lines(harmony_angles, harmony_type, opts \\ []) do
    radius = Keyword.get(opts, :radius, @ascii_radius)
    thickness = Keyword.get(opts, :thickness, 0.4)
    x_scale = 2.0

    lines =
      for y_pair <- 0..(radius - 1) do
        y_top = y_pair * 2 - radius
        y_bot = y_top + 1

        chars =
          for x_cell <- round(-radius * x_scale)..round(radius * x_scale) do
            x = x_cell / x_scale
            top_color = pixel_color_at(x, y_top, radius, harmony_angles, thickness)
            bot_color = pixel_color_at(x, y_bot, radius, harmony_angles, thickness)
            render_half_block(top_color, bot_color)
          end

        IO.iodata_to_binary(chars)
      end

    label = " #{harmony_display_name(harmony_type)} "
    center_line = div(length(lines), 2)

    lines
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      if idx == center_line, do: insert_label_in_line(line, label), else: line
    end)
  end

  @doc """
  Computes the harmony colors for a given type and base RGB.
  """
  @spec compute_harmony(rgb(), atom()) :: [rgb()]
  def compute_harmony(rgb, harmony_type) do
    case harmony_type do
      :complementary -> Harmonies.complementary(rgb)
      :analogous -> Harmonies.analogous(rgb)
      :triad -> Harmonies.triad(rgb)
      :square -> Harmonies.square(rgb)
      :monochromatic -> Harmonies.monochromatic(rgb)
      :split_complementary -> Harmonies.split_complementary(rgb)
      :compound -> Harmonies.compound(rgb)
      _ -> []
    end
  end

  @doc """
  Extracts HSL hue angles from a list of RGB tuples.
  """
  @spec extract_angles([rgb()]) :: [number()]
  def extract_angles(rgbs) do
    Enum.map(rgbs, fn rgb ->
      {h, _s, _l} = Converters.rgb_to_hsl(rgb)
      h
    end)
  end

  @doc """
  Renders color format information as formatted terminal output.
  """
  @spec render_color_formats(rgb()) :: :ok
  def render_color_formats({r, g, b} = rgb) do
    hex = Converters.rgb_to_hex(rgb)
    {h, s, l} = Converters.rgb_to_hsl(rgb)
    {hv, sv, v} = Converters.rgb_to_hsv(rgb)
    {c, m, y, k} = Converters.rgb_to_cmyk(rgb)
    xterm = Converters.rgb_to_xterm256(rgb)
    argb = {255, r, g, b}

    formats = [
      {"HEX", hex},
      {"RGB", "{#{r}, #{g}, #{b}}"},
      {"ARGB", "{#{elem(argb, 0)}, #{elem(argb, 1)}, #{elem(argb, 2)}, #{elem(argb, 3)}}"},
      {"HSL", "{#{Float.round(h, 1)}°, #{Float.round(s, 1)}%, #{Float.round(l, 1)}%}"},
      {"HSV", "{#{Float.round(hv, 1)}°, #{Float.round(sv, 1)}%, #{Float.round(v, 1)}%}"},
      {"CMYK",
       "{#{Float.round(c, 1)}%, #{Float.round(m, 1)}%, #{Float.round(y, 1)}%, #{Float.round(k, 1)}%}"},
      {"XTerm256", "#{xterm}"}
    ]

    Enum.each(formats, fn {label, value} ->
      IO.puts(
        "  #{Pote.Orchestrator.to_ansi({r, g, b})}#{String.pad_trailing(label, 10)}#{Alaja.ANSI.reset_attributes()} #{value}"
      )
    end)

    IO.puts("")
    :ok
  end

  @doc """
  Shows lighter/darker variants of a color.
  """
  @spec render_color_variants(rgb()) :: :ok
  def render_color_variants(rgb) do
    variants = [
      {"+50%", Harmonies.lighter(rgb, 0.5)},
      {"+20%", Harmonies.lighter(rgb, 0.2)},
      {"Base", rgb},
      {"-20%", Harmonies.darker(rgb, 0.2)},
      {"-50%", Harmonies.darker(rgb, 0.5)}
    ]

    line =
      Enum.map_join(variants, "  ", fn {label, {r, g, b}} ->
        "#{Pote.Orchestrator.to_ansi({r, g, b})}████#{Alaja.ANSI.reset_attributes()} #{label}"
      end)

    IO.puts("  #{line}")
    IO.puts("")
    :ok
  end

  @doc """
  Renders a list of color swatches with hex labels.
  """
  @spec render_swatch_list([rgb()]) :: :ok
  def render_swatch_list(colors) do
    Enum.each(colors, fn {r, g, b} = rgb ->
      hex = Converters.rgb_to_hex(rgb)

      IO.puts(
        "  #{Pote.Orchestrator.to_ansi({r, g, b})}████#{Alaja.ANSI.reset_attributes()} #{hex}  rgb(#{r},#{g},#{b})"
      )
    end)

    :ok
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # HARMONY DISPLAY NAMES
  # ═══════════════════════════════════════════════════════════════════════════

  @spec harmony_display_name(atom()) :: String.t()
  def harmony_display_name(:complementary), do: "COMPLEMENTARIA"
  def harmony_display_name(:analogous), do: "ANÁLOGA"
  def harmony_display_name(:triad), do: "TRÍADA"
  def harmony_display_name(:square), do: "CUADRADA"
  def harmony_display_name(:monochromatic), do: "MONOCROMÁTICA"
  def harmony_display_name(:split_complementary), do: "SPLIT-COMPLEMENTARIA"
  def harmony_display_name(:compound), do: "COMPUESTA"
  def harmony_display_name(_), do: "ARMONÍA"

  # ═══════════════════════════════════════════════════════════════════════════
  # ASCII WHEEL RENDERING
  # ═══════════════════════════════════════════════════════════════════════════

  @spec render_ascii_wheel([number()], atom(), keyword()) :: :ok
  defp render_ascii_wheel(harmony_angles, harmony_type, opts) do
    lines = get_ascii_wheel_lines(harmony_angles, harmony_type, opts)
    Enum.each(lines, &IO.puts("  " <> &1))
    :ok
  end

  @spec pixel_color_at(number(), number(), integer(), [number()], number()) ::
          rgb() | nil
  defp pixel_color_at(x, y, radius, harmony_angles, thickness_factor) do
    distance = :math.sqrt(x * x + y * y)
    ring_outer = radius * 1.0
    ring_inner = radius * (1.0 - thickness_factor)

    cond do
      distance >= ring_inner and distance <= ring_outer ->
        angle = :math.atan2(y, x)
        hue = rem(round(angle * 180 / :math.pi() + 360), 360)

        if harmony_marker?(hue, harmony_angles, 3) do
          {255, 255, 255}
        else
          hsl_to_rgb_255(hue, 100.0, 50.0)
        end

      distance < ring_inner ->
        {30, 30, 35}

      true ->
        nil
    end
  end

  @spec render_half_block(rgb() | nil, rgb() | nil) :: iodata()
  defp render_half_block(nil, nil), do: " "

  defp render_half_block({tr, tg, tb}, nil) do
    "#{Pote.Orchestrator.to_ansi({tr, tg, tb})}▀#{Alaja.ANSI.reset_attributes()}"
  end

  defp render_half_block(nil, {br, bg, bb}) do
    "#{Pote.Orchestrator.to_ansi({br, bg, bb})}▄#{Alaja.ANSI.reset_attributes()}"
  end

  defp render_half_block({tr, tg, tb}, {br, bg, bb}) do
    # Combined foreground + background escape
    "\e[38;2;#{tr};#{tg};#{tb};48;2;#{br};#{bg};#{bb}m▀\e[0m"
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # UTILITIES
  # ═══════════════════════════════════════════════════════════════════════════

  @spec resolve_rgb(Orchestrator.color_input()) :: rgb()
  defp resolve_rgb(input) when is_tuple(input) and tuple_size(input) == 3, do: input
  defp resolve_rgb(input), do: Orchestrator.to_rgb!(input)

  @spec hsl_to_rgb_255(number(), number(), number()) :: rgb()
  defp hsl_to_rgb_255(h, s, l), do: Converters.hsl_to_rgb({h * 1.0, s * 1.0, l * 1.0})

  @spec harmony_marker?(integer(), [number()], integer()) :: boolean()
  defp harmony_marker?(_hue, [], _tolerance), do: false

  defp harmony_marker?(hue, harmony_angles, tolerance) do
    Enum.any?(harmony_angles, fn target ->
      diff = abs(hue - target)
      diff = min(diff, 360 - diff)
      diff <= tolerance
    end)
  end

  @spec blend(rgb(), rgb(), float()) :: rgb()
  defp blend({r1, g1, b1}, {r2, g2, b2}, factor) do
    r = round(r1 + (r2 - r1) * factor)
    g = round(g1 + (g2 - g1) * factor)
    b = round(b1 + (b2 - b1) * factor)
    {min(max(r, 0), 255), min(max(g, 0), 255), min(max(b, 0), 255)}
  end

  @spec insert_label_in_line(String.t(), String.t()) :: String.t()
  defp insert_label_in_line(line, label) do
    plain = String.replace(line, ~r/\e\[[^m]*m/, "")
    visible_len = String.length(plain)
    label_len = String.length(label)

    if visible_len > label_len + 4 do
      center = div(visible_len, 2)
      start_pos = center - div(label_len, 2)
      before = String.slice(plain, 0, start_pos)
      after_text = String.slice(plain, (start_pos + label_len)..-1//1)
      styled_label = "\e[1;37;40m#{label}\e[0m"
      before <> styled_label <> after_text
    else
      line
    end
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # PNG WHEEL RENDERING
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Renders the color wheel as a PNG image and prints it to the terminal.

  This function generates a bitmap of the color wheel with harmony markers
  and outputs it using the detected image protocol (Kitty/iTerm2/Sixel).

  ## Parameters

    - `rgb_list` - List of RGB tuples representing colors to mark on the wheel
    - `opts` - Options (same as `get_ascii_wheel_lines`)
  """
  @spec render_png_wheel([rgb()], keyword()) :: iodata()
  def render_png_wheel(rgb_list, _opts \\ []) when is_list(rgb_list) do
    # 64x64 pixels total. Terminal cells are 2:1 (width:height).
    # For circle to appear circular, image must be 2:1 that gets stretched 2x.
    # So: 64 wide × 32 tall pixels → displayed as 8×8 cells (8px × 4px per cell = 2:1)
    pixel_width = 154
    pixel_height = 308
    display_cols = 14
    display_rows = 14

    radius_px = div(min(pixel_width, pixel_height), 2) - 4
    center_x = div(pixel_width, 2)
    center_y = div(pixel_height, 2)
    thickness_factor = 0.35

    # Extract hue angles from the rgb list
    harmony_angles = extract_angles(rgb_list)

    # Generate high-res pixel data (RGBA with alpha=0 for transparent)
    pixels =
      for y <- 0..(pixel_height - 1) do
        for x <- 0..(pixel_width - 1) do
          dx = x - center_x
          dy = y - center_y
          distance = :math.sqrt(dx * dx + dy * dy)

          png_pixel_color(dx, dy, distance, radius_px, thickness_factor, harmony_angles)
        end
      end

    # Generate PNG from pixels (RGBA)
    png_data = ImageRenderer.generate_png_rgba(pixels, pixel_width, pixel_height)
    b64 = Base.encode64(png_data)

    build_protocol_escape(b64, Terminal.image_protocol(), display_cols, display_rows)
  end

  defp png_pixel_color(dx, dy, distance, radius_px, thickness_factor, harmony_angles) do
    cond do
      distance >= radius_px * (1.0 - thickness_factor) and
          distance <= radius_px ->
        angle = :math.atan2(dy, dx)
        hue = rem(round(angle * 180 / :math.pi() + 360), 360)
        png_ring_pixel_color(hue, harmony_angles)

      distance < radius_px * (1.0 - thickness_factor) ->
        # Inner dark circle with full opacity
        {30, 30, 35, 255}

      true ->
        # Transparent background (alpha = 0)
        {0, 0, 0, 0}
    end
  end

  defp png_ring_pixel_color(hue, harmony_angles) do
    if harmony_marker?(hue, harmony_angles, 5) do
      # Draw white marker with full opacity
      {255, 255, 255, 255}
    else
      {r, g, b} = hsl_to_rgb_255(hue, 100.0, 50.0)
      {r, g, b, 255}
    end
  end

  defp build_protocol_escape(b64, protocol, display_cols, display_rows) do
    spacing = "\n"

    case protocol do
      :kitty ->
        chunks = chunk_string(b64, 4096)
        last_idx = length(chunks) - 1

        write_kitty_chunks_to_iodata(chunks, 1, display_cols, display_rows, last_idx, true) ++
          ["\e[u", spacing]

      :iterm2 ->
        # transparency=1 indicates we have alpha channel
        [
          "\e[s",
          "\e]1337;File=inline=1;width=#{display_cols};transparency=1:#{b64}\a",
          "\e[u",
          spacing
        ]

      _ ->
        # Fallback: return empty, ASCII mode will be used instead
        []
    end
  end

  # Returns iodata with escape codes instead of writing directly
  defp write_kitty_chunks_to_iodata(chunks, id, cols, rows, last_idx, is_transmission) do
    Enum.flat_map(chunks |> Enum.with_index(), fn {chunk, idx} ->
      write_kitty_chunk_to_iodata(chunk, idx, id, cols, rows, last_idx, is_transmission)
    end)
  end

  @dialyzer {:nowarn_function, {:write_kitty_chunk_to_iodata, 7}}
  defp write_kitty_chunk_to_iodata(chunk, idx, id, cols, rows, last_idx, is_transmission) do
    more = if idx < last_idx, do: 1, else: 0
    base = if is_transmission, do: "T", else: "t"

    if idx == 0 do
      ["\e[s", "\e_Gf=100,a=#{base},i=#{id},q=2,c=#{cols},r=#{rows},m=#{more};#{chunk}\e\\"]
    else
      ["\e_Gm=#{more};#{chunk}\e\\"]
    end
  end

  defp chunk_string(string, size) do
    string
    |> String.graphemes()
    |> Enum.chunk_every(size)
    |> Enum.map(&Enum.join/1)
  end
end
