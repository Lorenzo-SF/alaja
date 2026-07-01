defmodule Alaja.Wizard.Renderers do
  @moduledoc """
  Internal renderer implementations for `Alaja.Wizard`.

  Each renderer takes an `Alaja.Wizard.t/0` and returns an
  `Alaja.Buffer.t/0`. Renderers are pure: same input produces the
  same output.

  The five renderer names are deliberately neutral and reusable:

    :inline           all fields on one line, comma-separated
    :compact          two-column table (label | value)
    :stacked          label above value, blank line between fields
    :wizard           boxed form with a top progress marker
    :compact_wizard   boxed single-line form

  Call sites should dispatch via `Alaja.Wizard.render/2` rather than
  calling these directly.
  """

  alias Alaja.{Buffer, Wizard}

  # ANSI palette used by the boxed renderers for the borders.
  @border_fg {120, 120, 120}

  # ─── :inline ─────────────────────────────────────────────────────────
  # `Name: alice, Age: 30, Subscribe: true`
  def inline(%Wizard{} = w) do
    line = Enum.map_join(w.fields, ", ", &inline_pair/1)
    write_lines([line])
  end

  defp inline_pair(%{label: label, value: value, default: default, type: :boolean}) do
    rendered = render_value(value, default, :boolean)
    "#{label}: #{rendered}"
  end

  defp inline_pair(%{label: label, value: value, default: default, type: type}) do
    rendered = render_value(value, default, type)
    "#{label}: #{rendered}"
  end

  # ─── :compact ────────────────────────────────────────────────────────
  # Two-column layout:
  #   Name       alice
  #   Age        30
  #   Subscribe  true
  def compact(%Wizard{} = w) do
    label_width = w.fields |> Enum.map(&String.length(&1.label)) |> Enum.max(fn -> 0 end)
    lines = Enum.map(w.fields, &compact_line(&1, label_width))
    write_lines(lines)
  end

  defp compact_line(%{label: label, value: value, default: default, type: type}, lw) do
    padded = String.pad_trailing(label, lw + 2)
    "#{padded}#{render_value(value, default, type)}"
  end

  # ─── :stacked ────────────────────────────────────────────────────────
  # One field per row, label above value, blank line between fields.
  #   Name
  #     alice
  #
  #   Age
  #     30
  def stacked(%Wizard{} = w) do
    chunks =
      Enum.map(w.fields, fn f ->
        ["#{f.label}", "  #{render_value(f.value, f.default, f.type)}", ""]
      end)

    # Strip the trailing empty line of the last chunk for a tighter layout.
    lines = chunks |> List.flatten() |> Enum.reverse() |> tl() |> Enum.reverse()
    write_lines(lines)
  end

  # ─── :wizard ─────────────────────────────────────────────────────────
  # Boxed form with a top progress marker:
  #   ┌─ My Form (3 fields) ─────────────────┐
  #   │  Name       alice                    │
  #   │  Age        30                       │
  #   │  Subscribe  true                     │
  #   └──────────────────────────────────────┘
  def wizard(%Wizard{} = w) do
    body = compact(w)
    {bw, bh} = {body.width, body.height}
    title = w.title || "Wizard"
    top = "── #{title} (#{length(w.fields)} fields) "

    width = max(bw + 4, String.length(top) + 4)
    height = bh + 2

    buf = Buffer.new(width, height)

    # Top border with title
    buf = write_row(buf, 0, top_border_line(top, width), @border_fg)

    # Body lines, indented
    for y <- 0..(bh - 1), reduce: buf do
      acc ->
        src = read_row(body, y)
        row = "│ " <> String.pad_trailing(src, width - 4) <> " │"
        write_row_colored(acc, y + 1, row, @border_fg)
    end
    |> bottom_border(width - 1, height - 1)
  end

  # ─── :compact_wizard ─────────────────────────────────────────────────
  # Single-line boxed form:
  #   ┌─ My Form ──────────────────────────┐
  #   │  Name: alice | Age: 30 | ...       │
  #   └────────────────────────────────────┘
  def compact_wizard(%Wizard{} = w) do
    line = Enum.map_join(w.fields, " | ", &inline_pair/1)
    title = w.title || "Wizard"
    width = max(String.length(line) + 4, String.length(title) + 8)

    top = compact_wizard_top(title, width)
    body = "│ " <> String.pad_trailing(line, width - 4) <> " │"
    bottom = "└" <> String.duplicate("─", width - 2) <> "┘"

    write_lines_colored([top, body, bottom], @border_fg)
  end

  # ─── Value formatting ────────────────────────────────────────────────

  defp render_value(nil, default, _type), do: render_default(default)
  defp render_value(value, _default, :boolean), do: if(value, do: "[x]", else: "[ ]")
  defp render_value(value, _default, _type), do: to_string(value)

  defp render_default(nil), do: ""
  defp render_default(value), do: to_string(value)

  # ─── Buffer writing helpers ──────────────────────────────────────────

  defp write_lines(lines) do
    height = length(lines)
    width = lines |> Enum.map(&String.length/1) |> Enum.max(fn -> 0 end)

    lines
    |> Enum.with_index()
    |> Enum.reduce(Buffer.new(width, height), fn {line, y}, buf ->
      write_row(buf, y, line, nil)
    end)
  end

  defp write_lines_colored(lines, fg) do
    height = length(lines)
    width = lines |> Enum.map(&String.length/1) |> Enum.max(fn -> 0 end)

    lines
    |> Enum.with_index()
    |> Enum.reduce(Buffer.new(width, height), fn {line, y}, buf ->
      write_row_colored(buf, y, line, fg)
    end)
  end

  defp write_row(buf, y, str, _fg) do
    str
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buf, fn {ch, x}, b -> Buffer.put(b, x, y, ch) end)
  end

  defp write_row_colored(buf, y, str, fg) do
    str
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buf, fn {ch, x}, b -> Buffer.put(b, x, y, ch, fg) end)
  end

  defp read_row(%Buffer{width: w} = b, y) do
    for x <- 0..(w - 1), into: "", do: cell_at(b, x, y)
  end

  defp cell_at(%Buffer{} = b, x, y) do
    case Buffer.get(b, x, y) do
      %{char: ch} -> ch
      _ -> " "
    end
  end

  defp bottom_border(buf, width, y) do
    line = "└" <> String.duplicate("─", max(width - 2, 0)) <> "┘"
    write_row_colored(buf, y, String.slice(line, 0, buf.width), @border_fg)
  end

  defp top_border_line(title, width) do
    raw = "┌" <> String.pad_trailing(title, max(width - 2, 0), "─")
    String.slice(raw, 0, width - 1) <> "┐"
  end

  defp compact_wizard_top(title, width) do
    raw = "┌─ #{title} " <> String.pad_trailing("", max(width - String.length(title) - 5, 0), "─")
    String.slice(raw, 0, width - 1) <> "┐"
  end
end
