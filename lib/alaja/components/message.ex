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
  alias Alaja.Cell
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

  @doc """
  Convenience renderer for the CLI command. Takes a text string, a
  type (`:success | :error | :warning | :info | ...`), and a style
  map or keyword list. Returns an `Alaja.Buffer.t/0` ready to be
  converted to iolist or written to the terminal.

  Recognised style opts (all optional):

    * `:color` — atom, RGB tuple, or hex string
    * `:bold` / `:italic` / `:underline` / `:dim` / `:blink` /
      `:reverse` / `:hidden` / `:strikethrough` — boolean
    * `:padding` — non-negative integer
    * `:addline` — extra text printed below the message
  """
  @spec render(String.t(), atom(), keyword() | map()) :: Buffer.t()
  def render(text, type, opts \\ [])
      when is_binary(text) and is_atom(type) and (is_list(opts) or is_map(opts)) do
    opts_map = if is_list(opts), do: Map.new(opts), else: opts
    fg = resolve_color(Map.get(opts_map, :color)) || type_fg(type)

    effects =
      []
      |> maybe_effect(:bold, Map.get(opts_map, :bold, false))
      |> maybe_effect(:italic, Map.get(opts_map, :italic, false))
      |> maybe_effect(:underline, Map.get(opts_map, :underline, false))
      |> maybe_effect(:strikethrough, Map.get(opts_map, :strikethrough, false))
      |> maybe_effect(:dim, Map.get(opts_map, :dim, false))
      |> maybe_effect(:blink, Map.get(opts_map, :blink, false))
      |> maybe_effect(:reverse, Map.get(opts_map, :reverse, false))
      |> maybe_effect(:hidden, Map.get(opts_map, :hidden, false))

    chunks = [
      %ChunkText{
        text: text,
        color: fg,
        effects: effects
      }
    ]

    info = %MessageInfo{
      chunks: chunks,
      align: :left,
      padding: Map.get(opts_map, :padding, 0),
      add_line:
        case Map.get(opts_map, :addline) do
          nil -> :none
          extra -> %ChunkText{text: extra, color: fg}
        end
    }

    render(info)
  end

  defp type_fg(:success), do: {0xA6, 0xE3, 0xA1}
  defp type_fg(:error), do: {0xF3, 0x8B, 0xA8}
  defp type_fg(:warning), do: {0xF9, 0xE2, 0xAF}
  defp type_fg(:info), do: {0x89, 0xB4, 0xFA}
  defp type_fg(:debug), do: {0xCB, 0xA6, 0xF7}
  defp type_fg(:notice), do: {0x94, 0xE2, 0xD5}
  defp type_fg(:critical), do: {0xF3, 0x8B, 0xA8}
  defp type_fg(:alert), do: {0xF3, 0x8B, 0xA8}
  defp type_fg(:emergency), do: {0xF3, 0x8B, 0xA8}
  defp type_fg(:happy), do: {0xF5, 0xC2, 0xE7}
  defp type_fg(:sad), do: {0x94, 0xE2, 0xD5}
  defp type_fg(_), do: nil

  defp resolve_color(nil), do: nil
  defp resolve_color({_r, _g, _b} = rgb), do: %Pote.ColorInfo{rgb: rgb}

  defp resolve_color(name) when is_atom(name) do
    case Pote.Orchestrator.to_rgb(name) do
      {:ok, rgb} -> %Pote.ColorInfo{rgb: rgb}
      _ -> nil
    end
  end

  defp resolve_color(hex) when is_binary(hex) do
    case Pote.parse(hex) do
      {:ok, {r, g, b}} -> %Pote.ColorInfo{rgb: {r, g, b}}
      _ -> nil
    end
  end

  defp maybe_effect(list, _effect, false), do: list
  defp maybe_effect(list, effect, true), do: [effect | list]

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
    effects = resolve_chunk_effects(chunk)

    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      if x + idx < buf.width do
        # Use update_cell with a Cell carrying effects so the printer
        # later emits bold/italic/underline SGR codes. Buffer.put/6
        # doesn't have an effects slot, hence the explicit Cell path.
        cell = Cell.new(char, fg, nil, effects: effects)
        Buffer.update_cell(buf, x + idx, y, cell)
      else
        buf
      end
    end)
  end

  # `ChunkText.effects` may be a list of atoms (the legacy CLI shape)
  # or an `%EffectInfo{}` struct (used by the rest of the codebase).
  # Normalise both into a plain list of atoms so Cell.new can take it.
  defp resolve_chunk_effects(%ChunkText{effects: effects}) when is_list(effects), do: effects

  defp resolve_chunk_effects(%ChunkText{effects: %Alaja.Structures.EffectInfo{} = ei}) do
    ei
    |> Alaja.Structures.EffectInfo.to_ansi()
    |> case do
      "" -> []
      _ -> effects_from_struct(ei)
    end
  end

  defp resolve_chunk_effects(_), do: []

  defp effects_from_struct(%Alaja.Structures.EffectInfo{} = ei) do
    [
      {:bold, :bold},
      {:dim, :dim},
      {:italic, :italic},
      {:underline, :underline},
      {:blink, :blink},
      {:reverse, :reverse},
      {:invert, :invert},
      {:hidden, :hidden},
      {:strikethrough, :strikethrough}
    ]
    |> Enum.flat_map(fn {field, atom} -> if Map.get(ei, field), do: [atom], else: [] end)
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
