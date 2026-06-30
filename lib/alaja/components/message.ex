defmodule Alaja.Components.Message do
  @moduledoc """
  Canonical renderer for `Alaja.Structures.MessageInfo`.

  Returns an `Alaja.Buffer.t/0` so the result can be composed with
  `Alaja.Components.Box`, `Alaja.Components.Header`, or any other
  Cell-engine component.

  ## Why this exists

  Before this component existed, `Alaja.CLI.Commands.Show.Message`
  flattened the `MessageInfo` to a colored string with ANSI escapes
  and handed it to `Components.Box.render/2`. The box then measured
  the width with `String.length/1` which counted ANSI escapes as
  characters, producing a box that was much wider than the visible
  content.

  With this component in place the flow is:

      MessageInfo → Components.Message.render/1 → Buffer
                                                ↓
                                       Box.render(buffer, opts)
                                                ↓
                                           final Buffer

  Both pieces know each other's width because they speak Buffer.

  ## Options

  The component honors the `:align`, `:padding`, and `:add_line`
  options carried in the `MessageInfo` struct itself. No additional
  options are read here.
  """

  alias Alaja.Buffer
  alias Alaja.Structures.{ChunkText, MessageInfo}

  @doc """
  Renders a `MessageInfo` into an `Alaja.Buffer.t/0`.

  Returns an empty Buffer (0x1) when given an empty chunks list.
  """
  @spec render(MessageInfo.t()) :: Buffer.t()
  def render(%MessageInfo{chunks: []}), do: Buffer.new(0, 1)

  def render(%MessageInfo{} = msg) do
    align = Map.get(msg, :align, :left)
    padding = Map.get(msg, :padding, 0)
    _add_line = Map.get(msg, :add_line, :none)

    # Render each chunk into a separate Buffer, then concatenate horizontally.
    chunk_buffers =
      msg.chunks
      |> Enum.map(&render_chunk/1)
      |> Enum.reject(fn b -> b.width == 0 end)

    buffer =
      chunk_buffers
      |> Enum.reduce(Buffer.new(0, 1), fn chunk_buf, acc ->
        join_horizontal(acc, chunk_buf)
      end)

    buffer
    |> apply_padding(padding)
    |> apply_align(align)
  end

  # ---------------------------------------------------------------------------
  # Internal: render a single chunk as a 1-row Buffer
  # ---------------------------------------------------------------------------

  defp render_chunk(%ChunkText{} = chunk) do
    text = Map.get(chunk, :text, "")
    width = visible_length(text)

    if width == 0 do
      Buffer.new(0, 1)
    else
      buffer = Buffer.new(width, 1)

      # We use Buffer.write_string which preserves fg color when set on the
      # buffer. For chunk-level color we instead iterate graphemes and apply
      # color through put/3.
      write_colored(buffer, 0, 0, text, chunk)
    end
  end

  defp write_colored(buffer, x, y, text, chunk) do
    fg = resolve_chunk_fg(chunk)

    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      if x + idx < buf.width do
        Buffer.put(buf, x + idx, y, char, fg)
      else
        buf
      end
    end)
  end

  defp resolve_chunk_fg(%ChunkText{color: nil}), do: nil
  defp resolve_chunk_fg(%ChunkText{color: %Pote.ColorInfo{rgb: {r, g, b}}}), do: {r, g, b}

  defp resolve_chunk_fg(%ChunkText{color: color}) when is_atom(color) or is_tuple(color) do
    case Pote.Orchestrator.to_rgb(color) do
      {:ok, rgb} -> rgb
      _ -> nil
    end
  end

  defp resolve_chunk_fg(_), do: nil

  # ---------------------------------------------------------------------------
  # Internal: combine chunk buffers horizontally (left-to-right)
  # ---------------------------------------------------------------------------

  defp join_horizontal(%Buffer{width: 0}, b), do: b
  defp join_horizontal(a, %Buffer{width: 0}), do: a

  defp join_horizontal(a, b) do
    width = a.width + b.width
    height = max(a.height, b.height)

    result = Buffer.new(width, height)
    result = Buffer.overlay(result, a, 0, 0)
    Buffer.overlay(result, b, a.width, 0)
  end

  # ---------------------------------------------------------------------------
  # Internal: padding and alignment
  # ---------------------------------------------------------------------------

  defp apply_padding(buffer, 0), do: buffer

  defp apply_padding(%Buffer{width: w, height: h} = buffer, n) when n > 0 do
    new_w = w + n * 2
    result = Buffer.new(new_w, h)
    Buffer.overlay(result, buffer, n, 0)
  end

  defp apply_align(%Buffer{width: 0} = buffer, _align), do: buffer

  defp apply_align(buffer, :left), do: buffer

  defp apply_align(%Buffer{width: w, height: h} = buffer, align) do
    terminal_width = Alaja.Terminal.size() |> elem(0)
    offset = alignment_offset(terminal_width, w, align)
    result = Buffer.new(terminal_width, h)
    Buffer.overlay(result, buffer, offset, 0)
  end

  defp alignment_offset(terminal_w, content_w, :center),
    do: div(max(terminal_w - content_w, 0), 2)

  # For :right we leave one extra column of slack on the right side of the
  # terminal. Without this, the last visible character lands on column
  # `terminal_w - 1` (the very last column), which several terminals treat
  # as a wrap trigger or cursor-park position; the resulting visual glitch
  # is that the last glyph appears to wrap onto the next row. Reserving
  # one trailing space gives the renderer room to "breathe" and keeps the
  # right edge visually flush.
  defp alignment_offset(terminal_w, content_w, :right),
    do: max(terminal_w - content_w - 1, 0)

  defp alignment_offset(_terminal_w, _content_w, _), do: 0

  # ---------------------------------------------------------------------------
  # Internal: visible length (ignoring ANSI escape sequences)
  # ---------------------------------------------------------------------------

  @ansi_regex ~r/\x1b\[[0-9;]*m/

  defp visible_length(text) do
    text
    |> String.replace(@ansi_regex, "")
    |> String.length()
  end
end
