defmodule Alaja.Components.Pulsar do
  @moduledoc """
  Pulsar/radar animation component with gradient wave effect.

  Renders a rectangular area with content (text or image) in the center,
  surrounded by characters that animate with a pulse/radar wave effect.

  Uses the Cell/Buffer engine for proper rendering.

  ## Options

  - `:width` — total width in characters (default: 40)
  - `:height` — total height in lines (default: 7)
  - `:text` — central text to display
  - `:content_type` — `:text` or `:image` (default: `:text`)
  - `:content_position_x` — X offset for content within pulsar (default: center)
  - `:content_position_y` — Y offset for content within pulsar (default: center)
  - `:pulse_chars` — characters used for pulse effect (default: ["░", "▒", "▓", "█"])
  - `:colors` — list of RGB tuples for gradient (default: [{0, 180, 216}])
  - `:speed` — animation speed in ms (default: 100)
  - `:direction` — `:out` or `:in` wave direction (default: :out)
  - `:align` — text alignment (:left, :center, :right; default: :center)
  """

  alias Alaja.ANSI
  alias Alaja.Buffer
  alias Alaja.Cell
  alias Alaja.Components.Box
  alias Alaja.ImageRenderer

  @default_pulse_chars ["░", "▒", "▓", "█"]
  @default_colors [:primary]
  @default_width 40
  @default_height 7

  @doc """
  Renders a single frame of the pulsar animation.

  Returns iodata representing the current frame.
  """
  @spec render_frame(String.t(), non_neg_integer(), keyword()) :: Buffer.t()
  def render_frame(text, frame, opts \\ []) do
    width = Keyword.get(opts, :width, @default_width)
    height = Keyword.get(opts, :height, @default_height)

    pulse_chars =
      opts
      |> Keyword.get(:pulse_chars, @default_pulse_chars)
      |> then(fn
        [] -> @default_pulse_chars
        chars -> chars
      end)

    colors =
      opts
      |> Keyword.get(:colors, @default_colors)
      |> Enum.map(&resolve_pulsar_color/1)

    direction = Keyword.get(opts, :direction, :out)
    content_type = Keyword.get(opts, :content_type, :text)
    content_x = Keyword.get(opts, :content_position_x, nil)
    content_y = Keyword.get(opts, :content_position_y, nil)

    text_lines = String.split(text, "\n")
    text_height = length(text_lines)
    max_text_width = text_lines |> Enum.map(&String.length/1) |> Enum.max(fn -> 0 end)

    content_start =
      calc_content_position(content_x, content_y, width, height, max_text_width, text_height)

    buffer = Buffer.new(width, height)

    pulse_config = %{
      width: width,
      height: height,
      frame: frame,
      pulse_chars: pulse_chars,
      colors: colors,
      direction: direction,
      content_start: content_start,
      text_width: max_text_width,
      text_height: text_height,
      char_count: length(pulse_chars),
      color_count: length(colors),
      max_dist: :math.sqrt(div(width, 2) * div(width, 2) + div(height, 2) * div(height, 2)),
      # Center of animation is the content position (where the text/image is)
      center_x: elem(content_start, 0) + div(max_text_width, 2),
      center_y: elem(content_start, 1) + div(text_height, 2)
    }

    buffer = fill_pulse_background(buffer, pulse_config)
    buffer = write_content(buffer, text_lines, content_start, colors, content_type)

    render_buffer(buffer)
  end

  defp calc_content_position(nil, nil, width, height, text_width, text_height) do
    {div(width - text_width, 2), div(height - text_height, 2)}
  end

  defp calc_content_position(content_x, nil, _width, height, _text_width, text_height) do
    {content_x, div(height - text_height, 2)}
  end

  defp calc_content_position(nil, content_y, width, _height, text_width, _text_height) do
    {div(width - text_width, 2), content_y}
  end

  defp calc_content_position(content_x, content_y, _width, _height, _text_width, _text_height) do
    {content_x, content_y}
  end

  defp fill_pulse_background(buffer, config) do
    %{
      width: width,
      height: height,
      content_start: content_start,
      text_width: text_width,
      text_height: text_height
    } = config

    {content_start_x, content_start_y} = content_start
    content_end_x = content_start_x + text_width - 1
    content_end_y = content_start_y + text_height - 1

    cells =
      for y <- 0..(height - 1), x <- 0..(width - 1) do
        if inside_content?(x, y, content_start_x, content_end_x, content_start_y, content_end_y) do
          Cell.empty()
        else
          render_pulse_cell(x, y, config)
        end
      end

    cells
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {cell, idx}, acc ->
      Buffer.update_cell(acc, rem(idx, width), div(idx, width), cell)
    end)
  end

  defp inside_content?(x, y, start_x, end_x, start_y, end_y) do
    x >= start_x and x <= end_x and y >= start_y and y <= end_y
  end

  defp render_pulse_cell(x, y, config) do
    %{
      frame: frame,
      pulse_chars: pulse_chars,
      colors: colors,
      direction: direction,
      char_count: char_count,
      color_count: color_count,
      max_dist: max_dist,
      center_x: center_x,
      center_y: center_y
    } = config

    dx = x - center_x
    dy = y - center_y
    distance = :math.sqrt(dx * dx + dy * dy)
    normalized_dist = if max_dist > 0, do: distance / max_dist, else: 0

    wave_phase = calculate_wave_phase(frame, distance, char_count, direction)
    intensity = calculate_intensity(normalized_dist, wave_phase, char_count, direction)

    {r, g, b} = Enum.at(colors, rem(wave_phase, color_count))
    pulse_char = Enum.at(pulse_chars, rem(wave_phase, char_count))

    Cell.new(pulse_char, {round(r * intensity), round(g * intensity), round(b * intensity)})
  end

  defp calculate_wave_phase(frame, distance, char_count, :out) do
    rem(frame + round(distance * 1.5), char_count * 3)
  end

  defp calculate_wave_phase(frame, distance, char_count, :in) do
    max_val = char_count * 3
    rem(max_val - frame + round(distance * 1.5), max_val)
  end

  defp calculate_intensity(normalized_dist, wave_phase, char_count, :out) do
    wave_progress = rem(wave_phase, char_count * 3) / (char_count * 3)
    base_intensity = 1.0 - normalized_dist * 0.6
    pulse_intensity = 0.4 + 0.6 * :math.sin(wave_progress * :math.pi() * 2)
    max(0.15, base_intensity * pulse_intensity)
  end

  defp calculate_intensity(normalized_dist, wave_phase, char_count, :in) do
    wave_progress = rem(wave_phase, char_count * 3) / (char_count * 3)
    base_intensity = 0.4 + 0.6 * (1.0 - normalized_dist * 0.6)
    pulse_intensity = 0.4 + 0.6 * :math.sin(wave_progress * :math.pi() * 2)
    max(0.15, base_intensity * pulse_intensity)
  end

  defp write_content(buffer, _text_lines, _content_start, _colors, :image) do
    buffer
  end

  defp write_content(buffer, text_lines, content_start, colors, :text) do
    {start_x, start_y} = content_start
    {r, g, b} = hd(colors)

    text_lines
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, dy}, buf ->
      write_line_to_buffer(buf, line, dy, start_x, start_y, r, g, b)
    end)
  end

  defp write_line_to_buffer(buffer, line, dy, start_x, start_y, r, g, b) do
    line
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, dx}, acc ->
      x = start_x + dx
      y = start_y + dy

      if Buffer.valid_coord?(acc, x, y) do
        Buffer.update_cell(acc, x, y, Cell.new(char, {r, g, b}))
      else
        acc
      end
    end)
  end

  defp render_buffer(buffer) do
    buffer
  end

  defp resolve_pulsar_color(term) when is_atom(term) and not is_nil(term) do
    Alaja.Cell.resolve_theme_color(term) || {0, 0, 0}
  end

  defp resolve_pulsar_color(term), do: term

  @doc false
  @deprecated "Use render_buffer/1 directly. Kept for backward compat."
  def render_buffer_iodata(buffer) do
    for y <- 0..(buffer.height - 1) do
      for x <- 0..(buffer.width - 1) do
        Cell.to_ansi(Buffer.get(buffer, x, y))
      end
      |> Enum.join("")
    end
    |> Enum.join("\n")
  end

  @doc """
  Renders a single frame of the pulsar animation as pixel data.

  Returns pixel data as a list of rows, each row a list of {r, g, b} tuples.
  Used when content_type is :image for compositing with image protocols.
  """
  @spec render_frame_pixels(String.t(), non_neg_integer(), keyword()) ::
          {:ok, [[{0..255, 0..255, 0..255}]]} | {:error, String.t()}
  def render_frame_pixels(image_path, frame, opts \\ []) do
    width = Keyword.get(opts, :width, @default_width)
    height = Keyword.get(opts, :height, @default_height)

    pulse_chars =
      opts
      |> Keyword.get(:pulse_chars, @default_pulse_chars)
      |> then(fn
        [] -> @default_pulse_chars
        chars -> chars
      end)

    colors =
      opts
      |> Keyword.get(:colors, @default_colors)
      |> Enum.map(&resolve_pulsar_color/1)

    direction = Keyword.get(opts, :direction, :out)
    content_x = Keyword.get(opts, :content_position_x, nil)
    content_y = Keyword.get(opts, :content_position_y, nil)

    with {:ok, image_pixels} <- load_contained_image(image_path, width, height) do
      img_height = length(image_pixels)
      img_width = length(List.first(image_pixels, []))

      content_start =
        calc_content_position(content_x, content_y, width, height, img_width, img_height)

      {content_start_x, content_start_y} = content_start
      content_end_x = content_start_x + img_width - 1
      content_end_y = content_start_y + img_height - 1

      char_count = length(pulse_chars)
      color_count = length(colors)

      max_dist = :math.sqrt(div(width, 2) * div(width, 2) + div(height, 2) * div(height, 2))
      center_x = elem(content_start, 0) + div(img_width, 2)
      center_y = elem(content_start, 1) + div(img_height, 2)

      config = %{
        image_pixels: image_pixels,
        content_bounds: {content_start_x, content_end_x, content_start_y, content_end_y},
        center: {center_x, center_y},
        frame: frame,
        max_dist: max_dist,
        char_count: char_count,
        color_count: color_count,
        direction: direction,
        colors: colors
      }

      pixels =
        for y <- 0..(height - 1) do
          render_row(x: 0, width: width, y: y, config: config)
        end

      {:ok, pixels}
    end
  end

  # Escala la imagen para que quepa dentro del box manteniendo el aspect
  # ratio (contain): primero por ancho (height: 0) y, si el alto resultante
  # excede el box, se reescala proporcionalmente por alto con un ancho menor.
  # La imagen nunca se estira al box completo, así `content_position_x/y`
  # pueden ubicarla dentro del pulsar como si fuera texto.
  defp load_contained_image(path, width, height) do
    do_load_contained(path, width, height, 3)
  end

  defp do_load_contained(path, width, height, attempts) when attempts > 0 do
    case ImageRenderer.load_image_pixels(path, width: max(1, width), height: 0) do
      {:ok, pixels} when length(pixels) > height ->
        new_width = max(1, round(width * height / length(pixels)))
        do_load_contained(path, new_width, height, attempts - 1)

      other ->
        other
    end
  end

  defp do_load_contained(_path, _width, _height, 0) do
    {:error, "image too tall for the pulsar box"}
  end

  defp render_pixel(x, y, config) do
    %{
      image_pixels: image_pixels,
      content_bounds: {csx, cex, csy, cey},
      center: {cx, cy},
      frame: frame,
      max_dist: max_dist,
      char_count: char_count,
      color_count: color_count,
      direction: direction,
      colors: colors
    } = config

    if inside_content?(x, y, csx, cex, csy, cey) do
      img_y = y - csy
      img_x = x - csx
      img_row = Enum.at(image_pixels, img_y, [])
      Enum.at(img_row, img_x, {0, 0, 0})
    else
      dx = x - cx
      dy = y - cy
      distance = :math.sqrt(dx * dx + dy * dy)
      normalized_dist = if max_dist > 0, do: distance / max_dist, else: 0

      wave_phase = calculate_wave_phase(frame, distance, char_count, direction)
      intensity = calculate_intensity(normalized_dist, wave_phase, char_count, direction)

      {r, g, b} = Enum.at(colors, rem(wave_phase, color_count))
      {round(r * intensity), round(g * intensity), round(b * intensity)}
    end
  end

  defp render_row(x: start_x, width: width, y: y, config: config) do
    for x <- start_x..(start_x + width - 1) do
      render_pixel(x, y, config)
    end
  end

  @doc """
  Returns the default options for the pulsar component.
  """
  @spec default_opts() :: keyword()
  def default_opts do
    [
      width: @default_width,
      height: @default_height,
      pulse_chars: @default_pulse_chars,
      colors: @default_colors,
      speed: 100,
      direction: :out,
      align: :center,
      content_type: :text
    ]
  end

  # ---------------------------------------------------------------------------
  # Animation runtime — drives the loop that calls render_frame/3 and
  # render_frame_pixels/3 each tick. The CLI is a thin wrapper that
  # parses argv into `opts` (component opts) and `global` (placement).
  # ---------------------------------------------------------------------------

  @doc """
  Runs the pulsar animation in the terminal. Blocks until `duration`
  (ms) elapses; returns `:ok` when finished.

  `opts` carries component-level settings (width, height, speed,
  direction, colors, pulse_chars, align, content_type, content_position_x,
  content_position_y, image_path, duration). `global` is a keyword list
  with positioning flags from the CLI: `raw`, `pos_x`, `pos_y`, `box`,
  `box_title`, `box_border`, `box_color`, `align`, `no_color`. Any
  unknown key is ignored, so the CLI can pass the whole global struct.
  """
  @spec run(String.t(), keyword(), keyword()) :: :ok
  def run(text, opts, global) when is_binary(text) and is_list(opts) do
    duration = Keyword.get(opts, :duration)
    speed = Keyword.get(opts, :speed, 100)
    content_type = Keyword.get(opts, :content_type, :text)

    case content_type do
      :image -> run_image(text, opts, global, speed, duration)
      _ -> run_text(text, opts, global, speed, duration)
    end
  end

  defp run_text(text, opts, global, speed, duration) do
    height = Keyword.get(opts, :height, @default_height)
    box_height = if global[:box], do: height + 2, else: height
    use_abs = global[:raw] || (global[:pos_x] || 0) > 0 || (global[:pos_y] || 0) > 0
    start_x = (global[:pos_x] || 0) + 1
    start_y = (global[:pos_y] || 0) + 1
    align = global[:align] || :left
    internal_align = Keyword.get(opts, :align, :center)

    left_pad =
      if align == internal_align,
        do: 0,
        else: calculate_left_padding(align, Keyword.get(opts, :width, @default_width))

    # Abort cleanly when the animation would not fit vertically. Without
    # this guard, the relative cursor-up escape would walk past row 1 and
    # wipe unrelated content above the pulsar.
    term_h =
      case :io.rows() do
        {:ok, h} -> h
        _ -> 24
      end

    if start_y + box_height - 1 > term_h do
      IO.write(
        :stderr,
        "alaja pulsar: not enough vertical space (#{start_y + box_height - 1} > #{term_h}); aborting\n"
      )

      :ok
    else
      IO.write(ANSI.hide_cursor())

      try do
        ctx = %{
          start_x: start_x,
          start_y: start_y,
          left_pad: left_pad,
          box_height: box_height,
          use_abs: use_abs,
          no_color: global[:no_color] || false
        }

        animate_text_loop(text, opts, global, speed, duration, ctx)
      after
        IO.write(ANSI.show_cursor())
      end

      :ok
    end
  end

  defp animate_text_loop(text, opts, global, speed, duration, ctx, frame \\ 0) do
    cond do
      duration && duration > 0 && frame * speed >= duration ->
        IO.write([ANSI.clear_line_down(), ANSI.show_cursor()])
        :ok

      true ->
        frame_output = render_frame(text, frame, opts)
        output = wrap_if_boxed(frame_output, global, ctx.no_color)
        write_text_frame(output, frame, ctx)
        :timer.sleep(speed)
        animate_text_loop(text, opts, global, speed, duration, ctx, frame + 1)
    end
  end

  # Raw mode: redraw each line at its target (start_x, start_y + row).
  # sync_output_start/end batches the frame so the terminal renders it in
  # one shot (no flicker). Frame 0 also hides the cursor (only useful in
  # raw mode).
  defp write_text_frame(output, 0, %{use_abs: true} = ctx) do
    positioned = position_abs(output, ctx.start_x, ctx.start_y, ctx.left_pad)
    IO.write([ANSI.hide_cursor(), positioned])
  end

  defp write_text_frame(output, _frame, %{use_abs: true} = ctx) do
    positioned = position_abs(output, ctx.start_x, ctx.start_y, ctx.left_pad)
    IO.write([ANSI.sync_output_start(), positioned, ANSI.sync_output_end()])
  end

  # Relative mode: pad each line with spaces on the left, restore cursor
  # on frame N>0 so subsequent frames overwrite the previous.
  defp write_text_frame(output, 0, %{use_abs: false} = ctx) do
    padded = pad_left(output, ctx.left_pad)
    IO.write([ANSI.save_cursor(), padded])
  end

  defp write_text_frame(output, _frame, %{use_abs: false} = ctx) do
    padded = pad_left(output, ctx.left_pad)
    IO.write([ANSI.restore_cursor(), ANSI.clear_line_down(), padded])
  end

  defp position_abs(output, start_x, start_y, left_pad) do
    output
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.map_join(fn {line, row} ->
      ANSI.move_to(start_x + left_pad, start_y + row) <> line
    end)
  end

  defp pad_left(output, left_pad) do
    output
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.map_join("\n", fn line -> String.duplicate(" ", left_pad) <> line end)
  end

  defp wrap_if_boxed(buffer, global, _no_color) do
    if global[:box] do
      box_opts =
        []
        |> maybe_add(:title, global[:box_title])
        |> maybe_add(:border, global[:box_border])
        |> maybe_add(:border_color, global[:box_color])

      buffer
      |> Box.render(box_opts)
      |> Buffer.to_iodata()
    else
      Buffer.to_iodata(buffer)
    end
  end

  defp calculate_left_padding(align, content_width) do
    terminal_width =
      case :io.columns() do
        {:ok, w} -> w
        _ -> 80
      end

    available = terminal_width - content_width

    case align do
      :left -> 0
      :center -> max(0, div(available, 2))
      :right -> max(0, available)
    end
  end

  defp run_image(text, opts, global, speed, duration) do
    image_path = Keyword.get(opts, :image_path)

    cond do
      is_nil(image_path) or image_path == "" ->
        IO.puts(:stderr, "Error: --image-path is required when using --content-type image")
        exit({:shutdown, 1})

      not File.exists?(image_path) ->
        IO.puts(:stderr, "Error: Image file not found: #{image_path}")
        exit({:shutdown, 1})

      true ->
        IO.write(ANSI.hide_cursor())

        try do
          animate_image_loop(text, opts, global, image_path, speed, duration)
        after
          IO.write(ANSI.show_cursor())
        end

        :ok
    end
  end

  defp animate_image_loop(text, opts, global, image_path, speed, duration, frame \\ 0) do
    if duration && duration > 0 && frame * speed >= duration do
      :ok
    else
      case render_frame_pixels(image_path, frame, opts) do
        {:ok, pixels} ->
          ctx = build_image_ctx(opts, global)
          write_image_frame(pixels, frame, ctx)
          :timer.sleep(speed)
          animate_image_loop(text, opts, global, image_path, speed, duration, frame + 1)

        {:error, reason} ->
          IO.puts(:stderr, "Error rendering image: #{reason}")
      end
    end
  end

  defp build_image_ctx(opts, global) do
    width = Keyword.get(opts, :width, @default_width)
    height = Keyword.get(opts, :height, @default_height)
    use_abs = global[:raw] || (global[:pos_x] || 0) > 0 || (global[:pos_y] || 0) > 0
    start_x = (global[:pos_x] || 0) + 1
    start_y = (global[:pos_y] || 0) + 1
    align = global[:align] || :left
    internal_align = Keyword.get(opts, :align, :center)

    left_pad =
      if align == internal_align,
        do: 0,
        else: calculate_left_padding(align, width)

    %{
      width: width,
      height: height,
      start_x: start_x,
      start_y: start_y,
      left_pad: left_pad,
      use_abs: use_abs
    }
  end

  defp write_image_frame(pixels, _frame, %{use_abs: true} = ctx) do
    IO.write(ANSI.move_to(ctx.start_x + ctx.left_pad, ctx.start_y))
    ImageRenderer.render(pixels, width: ctx.width, height: ctx.height, align: :left)
  end

  defp write_image_frame(pixels, 0, %{use_abs: false} = ctx) do
    IO.write(ANSI.save_cursor())
    if ctx.left_pad > 0, do: IO.write(String.duplicate(" ", ctx.left_pad))
    ImageRenderer.render(pixels, width: ctx.width, height: ctx.height, align: :left)
  end

  defp write_image_frame(pixels, _frame, %{use_abs: false} = ctx) do
    IO.write([ANSI.restore_cursor(), ANSI.clear_line_down()])
    if ctx.left_pad > 0, do: IO.write(String.duplicate(" ", ctx.left_pad))
    ImageRenderer.render(pixels, width: ctx.width, height: ctx.height, align: :left)
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)
end
