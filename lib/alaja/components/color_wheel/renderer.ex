defmodule Alaja.Components.ColorWheel.Renderer do
  @moduledoc false

  alias Alaja.Buffer
  alias Alaja.Cell
  alias Alaja.Components.ColorWheel.Harmonies
  alias Alaja.ImageRenderer
  alias Alaja.ImageTerminal, as: Terminal

  alias Pote
  alias Pote.Converters

  @type rgb :: Pote.rgb()

  @ascii_radius 10

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
      if harmony_type, do: Harmonies.harmony_display_name(harmony_type), else: nil

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

  defp half_block_cell(nil, nil), do: Cell.empty()
  defp half_block_cell({r, g, b}, nil), do: Cell.new("▀", {r, g, b})
  defp half_block_cell(nil, {r, g, b}), do: Cell.new("▄", {r, g, b})
  defp half_block_cell({tr, tg, tb}, {br, bg, bb}), do: Cell.new("▀", {tr, tg, tb}, {br, bg, bb})

  defp render_angles_for(rgb_list, opts) do
    case Keyword.fetch(opts, :harmony_angles) do
      {:ok, angles} when is_list(angles) ->
        angles

      _ ->
        Harmonies.extract_angles(rgb_list)
    end
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

    label = " #{Harmonies.harmony_display_name(harmony_type)} "
    center_line = div(length(lines), 2)

    lines
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      if idx == center_line, do: insert_label_in_line(line, label), else: line
    end)
  end

  @doc """
  Renders the ASCII half-block wheel to the terminal.
  """
  @spec render_ascii_wheel([number()], atom(), keyword()) :: :ok
  def render_ascii_wheel(harmony_angles, harmony_type, opts \\ []) do
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
    "#{Alaja.ANSI.fg(tr, tg, tb)}▀#{Alaja.ANSI.reset_attributes()}"
  end

  defp render_half_block(nil, {br, bg, bb}) do
    "#{Alaja.ANSI.fg(br, bg, bb)}▄#{Alaja.ANSI.reset_attributes()}"
  end

  defp render_half_block({tr, tg, tb}, {br, bg, bb}) do
    "\e[38;2;#{tr};#{tg};#{tb};48;2;#{br};#{bg};#{bb}m▀\e[0m"
  end

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
    pixel_width = 154
    pixel_height = 308
    display_cols = 14
    display_rows = 14

    radius_px = div(min(pixel_width, pixel_height), 2) - 4
    center_x = div(pixel_width, 2)
    center_y = div(pixel_height, 2)
    thickness_factor = 0.35

    harmony_angles = Harmonies.extract_angles(rgb_list)

    pixels =
      for y <- 0..(pixel_height - 1) do
        for x <- 0..(pixel_width - 1) do
          dx = x - center_x
          dy = y - center_y
          distance = :math.sqrt(dx * dx + dy * dy)

          png_pixel_color(dx, dy, distance, radius_px, thickness_factor, harmony_angles)
        end
      end

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
        {30, 30, 35, 255}

      true ->
        {0, 0, 0, 0}
    end
  end

  defp png_ring_pixel_color(hue, harmony_angles) do
    if harmony_marker?(hue, harmony_angles, 5) do
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
        [
          "\e[s",
          "\e]1337;File=inline=1;width=#{display_cols};transparency=1:#{b64}\a",
          "\e[u",
          spacing
        ]

      _ ->
        []
    end
  end

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
