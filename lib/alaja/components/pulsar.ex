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

  alias Alaja.Buffer
  alias Alaja.Cell
  alias Alaja.ImageRenderer

  @default_pulse_chars ["░", "▒", "▓", "█"]
  @default_colors [{0, 180, 216}]
  @default_width 40
  @default_height 7

  @doc """
  Renders a single frame of the pulsar animation.

  Returns iodata representing the current frame.
  """
  @spec render_frame(String.t(), non_neg_integer(), keyword()) :: iodata()
  def render_frame(text, frame, opts \\ []) do
    width = Keyword.get(opts, :width, @default_width)
    height = Keyword.get(opts, :height, @default_height)
    pulse_chars = Keyword.get(opts, :pulse_chars, @default_pulse_chars)
    colors = Keyword.get(opts, :colors, @default_colors)
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
    pulse_chars = Keyword.get(opts, :pulse_chars, @default_pulse_chars)
    colors = Keyword.get(opts, :colors, @default_colors)
    direction = Keyword.get(opts, :direction, :out)
    content_x = Keyword.get(opts, :content_position_x, nil)
    content_y = Keyword.get(opts, :content_position_y, nil)

    with {:ok, image_pixels} <- ImageRenderer.load_image_pixels(image_path, width: width, height: height) do
      img_height = length(image_pixels)
      img_width = length(List.first(image_pixels, []))

      content_start = calc_content_position(content_x, content_y, width, height, img_width, img_height)

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
end
