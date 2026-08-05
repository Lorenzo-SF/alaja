defmodule Alaja.CLI.Commands.Show.Pulsar.Renderer do
  @moduledoc false

  alias Alaja.Components.{Box, Pulsar}
  alias Alaja.{ANSI, Buffer, ImageRenderer}

  @doc false
  def print_verbose_frames(text, pulsar_opts) do
    Enum.each(0..19, fn frame ->
      frame_output =
        text
        |> Pulsar.render_frame(frame, pulsar_opts)
        |> Buffer.to_iodata()

      IO.puts(frame_output)
      IO.puts("")
    end)
  end

  @doc false
  def run_animation(text, pulsar_opts, global) do
    speed = Keyword.get(pulsar_opts, :speed, 100)
    width = Keyword.get(pulsar_opts, :width, 40)
    height = Keyword.get(pulsar_opts, :height, 7)
    content_type = Keyword.get(pulsar_opts, :content_type, :text)
    internal_align = Keyword.get(pulsar_opts, :align, :center)
    box_height = if global.box, do: height + 2, else: height

    left_pad =
      if global.align == internal_align do
        0
      else
        calculate_left_padding(global.align, width)
      end

    duration = Keyword.get(pulsar_opts, :duration)

    IO.write(ANSI.hide_cursor())

    case content_type do
      :image ->
        run_image_animation(text, pulsar_opts, global, speed, width, height, left_pad, duration)

      :text ->
        run_text_animation(text, pulsar_opts, global, speed, box_height, left_pad, duration)
    end
  end

  defp run_text_animation(text, pulsar_opts, global, speed, box_height, left_pad, duration) do
    start_pos = calculate_start_pos(global, left_pad)

    if global.raw do
      IO.write(ANSI.hide_cursor())
    end

    {term_h, _term_w} =
      case :io.rows() do
        {:ok, h} -> {h, 80}
        _ -> {24, 80}
      end

    {_, start_y} = start_pos

    if start_y + box_height - 1 > term_h do
      IO.write(
        :stderr,
        "alaja pulsar: not enough vertical space (#{start_y + box_height - 1} > #{term_h}); aborting\n"
      )

      if global.raw do
        IO.write(ANSI.show_cursor())
      end

      :ok
    else
      try do
        animate_loop(text, pulsar_opts, global, 0, speed, box_height, left_pad, start_pos, duration)
      after
        if global.raw do
          IO.write(ANSI.show_cursor())
        end
      end
    end
  end

  defp calculate_start_pos(global, _left_pad) do
    {global.pos_x + 1, global.pos_y + 1}
  end

  defp run_image_animation(text, pulsar_opts, global, speed, width, height, left_pad, duration) do
    image_path = Keyword.get(pulsar_opts, :image_path)

    if is_nil(image_path) or image_path == "" do
      IO.puts(:stderr, "Error: --image-path is required when using --content-type image")
      exit({:shutdown, 1})
    end

    if not File.exists?(image_path) do
      IO.puts(:stderr, "Error: Image file not found: #{image_path}")
      exit({:shutdown, 1})
    end

    try do
      opts = %{width: width, height: height, left_pad: left_pad}
      image_animate_loop(text, pulsar_opts, global, image_path, 0, speed, opts, duration)
    after
      IO.write(ANSI.show_cursor())
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

  defp animate_loop(text, pulsar_opts, global, frame, speed, box_height, left_pad, start_pos, duration) do
    if duration && duration > 0 && frame * speed >= duration do
      IO.write([ANSI.clear_line_down(), ANSI.show_cursor()])
      :ok
    else
      frame_output = Pulsar.render_frame(text, frame, pulsar_opts)
      output = wrap_if_boxed(frame_output, global)

      if global.raw do
        {start_x, start_y} = start_pos

        positioned =
          output
          |> IO.iodata_to_binary()
          |> String.split("\n")
          |> Enum.with_index()
          |> Enum.map_join(fn {line, row} ->
            ANSI.move_to(start_x + left_pad, start_y + row) <> line
          end)

        if frame == 0 do
          IO.write([ANSI.hide_cursor(), positioned])
        else
          # The frame buffer repaints every cell of the animation area, so
          # no explicit clear is needed. Synchronized output mode batches
          # the frame so the terminal renders it in one shot (no flicker).
          IO.write([ANSI.sync_output_start(), positioned, ANSI.sync_output_end()])
        end
      else
        padded_output =
          output
          |> IO.iodata_to_binary()
          |> String.split("\n")
          |> Enum.map_join("\n", fn line -> String.duplicate(" ", left_pad) <> line end)

        if frame == 0 do
          IO.write([ANSI.save_cursor(), padded_output])
        else
          IO.write([ANSI.restore_cursor(), ANSI.clear_line_down(), padded_output])
        end
      end

      :timer.sleep(speed)

      animate_loop(
        text,
        pulsar_opts,
        global,
        frame + 1,
        speed,
        box_height,
        left_pad,
        start_pos,
        duration
      )
    end
  end

  defp image_animate_loop(text, pulsar_opts, global, image_path, frame, speed, opts, duration) do
    %{width: width, height: height, left_pad: left_pad} = opts

    if duration && duration > 0 && frame * speed >= duration do
      IO.write(ANSI.show_cursor())
      :ok
    else
      case Pulsar.render_frame_pixels(image_path, frame, pulsar_opts) do
        {:ok, pixels} ->
          padded_pixels = apply_left_padding_pixels(pixels, left_pad)
          ImageRenderer.render(padded_pixels, width: width, height: height, align: :left)

          :timer.sleep(speed)
          image_animate_loop(text, pulsar_opts, global, image_path, frame + 1, speed, opts, duration)

        {:error, reason} ->
          IO.puts(:stderr, "Error rendering image: #{reason}")
      end
    end
  end

  defp apply_left_padding_pixels(pixels, 0), do: pixels

  defp apply_left_padding_pixels(pixels, left_pad) do
    padding_row = List.duplicate({0, 0, 0}, left_pad)
    Enum.map(pixels, fn row -> padding_row ++ row end)
  end

  defp wrap_if_boxed(frame_output, %{box: true} = global) do
    box_opts =
      []
      |> maybe_add(:title, global.box_title)
      |> maybe_add(:border, global.box_border)
      |> maybe_add(:border_color, global.box_color)

    frame_output
    |> Box.render(box_opts)
    |> Buffer.to_iodata()
  end

  defp wrap_if_boxed(frame_output, _global) do
    Buffer.to_iodata(frame_output)
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)
end
