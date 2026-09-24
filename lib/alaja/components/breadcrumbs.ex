defmodule Alaja.Components.Breadcrumbs do
  @moduledoc """
  Static breadcrumb navigation component for terminal output.

  Renders a path-like list of items with a separator.

  ## Usage

      iex> Alaja.Components.Breadcrumbs.print(["Home", "Projects", "Alaja"])
      # Home > Projects > Alaja

  ## Cell engine

  As of v0.3.0, `render/2` returns an `Alaja.Buffer.t/0` (or an empty
  list when given `[]`). Each item gets its own colour, with the last
  item rendered in `:current_color`.
  """

  alias Alaja.{Buffer, Cell}

  @default_separator "›"
  @default_item_color :primary
  @default_current_color :no_color
  @default_separator_color :debug

  @doc """
  Prints breadcrumbs to stdout.
  """
  @spec print([String.t()], keyword()) :: :ok
  def print(items, opts \\ []) do
    items
    |> render(opts)
    |> buffer_to_iodata()
    |> IO.write()

    IO.puts("")
  end

  @doc """
  Renders breadcrumbs to an `Alaja.Buffer.t/0` (single row, height 1).

  Returns `[]` for an empty list (legacy compat with the iodata API).
  """
  @spec render([String.t()], keyword()) :: Buffer.t()
  def render([], _opts), do: Buffer.new(0, 1)

  def render(items, opts) do
    separator = Keyword.get(opts, :separator, @default_separator)
    item_color = Keyword.get(opts, :item_color, @default_item_color)
    current_color = Keyword.get(opts, :current_color, @default_current_color)

    sep_color =
      case Keyword.get(opts, :separator_color) do
        [c | _] -> c
        nil -> @default_separator_color
        other -> other
      end

    # Allow both a single colour and a list of colours. When the user
    # passes a list for `:item_color` (or `:current_color`) we pick the
    # colour positionally for each item, cycling through the list.
    item_colors = expand_color_list(items, item_color, @default_item_color)
    last_idx = length(items) - 1

    current_colors = expand_current_colors(current_color, last_idx)

    sep_str = " #{separator} "
    total_w = total_width(items, sep_str, last_idx)

    buffer = Buffer.new(total_w, 1)
    x = 0

    ctx = %{
      last_idx: last_idx,
      current_colors: current_colors,
      item_colors: item_colors,
      item_color: item_color,
      sep_str: sep_str,
      sep_color: sep_color
    }

    items
    |> Enum.with_index()
    |> Enum.reduce({buffer, x}, fn {item, idx}, {buf, cx} -> step({buf, cx}, item, idx, ctx) end)
    |> elem(0)
  end

  # Number of cells each item occupies, plus the separator width when
  # the next item follows.
  defp total_width(items, sep_str, last_idx) do
    items
    |> Enum.with_index()
    |> Enum.reduce(0, fn {item, idx}, acc ->
      acc + String.length(item) + if(idx < last_idx, do: String.length(sep_str), else: 0)
    end)
  end

  # Normalise `:current_color` into a list indexed by item position.
  # When the caller passes a single value it is repeated across the
  # whole breadcrumb so the renderer can always index by position.
  defp expand_current_colors(current_color, last_idx) do
    if is_list(current_color) do
      current_color
    else
      List.duplicate(current_color || @default_current_color, max(last_idx + 1, 1))
    end
  end

  # One iteration of the breadcrumb rendering loop. Extracted from
  # `render/2` to keep its cyclomatic complexity, nesting depth, and
  # parameter count within credo's `--strict` limits.
  defp step({buf, cx}, item, idx, ctx) do
    color = color_for(idx, ctx.last_idx, ctx)
    item_w = String.length(item)
    buf = write_string(buf, cx, 0, item, color)

    if idx < ctx.last_idx do
      {write_string(buf, cx + item_w, 0, ctx.sep_str, ctx.sep_color),
       cx + item_w + String.length(ctx.sep_str)}
    else
      {buf, cx + item_w}
    end
  end

  defp color_for(idx, last_idx, ctx) do
    if idx == last_idx do
      Enum.at(ctx.current_colors, idx, Enum.at(ctx.current_colors, 0))
    else
      if is_nil(ctx.item_colors) do
        ctx.item_color
      else
        Enum.at(ctx.item_colors, idx, Enum.at(ctx.item_colors, 0))
      end
    end
  end

  defp expand_color_list(items, colors, default) when is_list(colors),
    do:
      Enum.map(0..(length(items) - 1)//1, fn i ->
        Enum.at(colors, i, Enum.at(colors, 0) || default)
      end)
      |> Enum.map(&(&1 || default))

  defp expand_color_list(_items, _color, _default),
    # marker: use the single colour
    do: nil

  defp write_string(buffer, x, y, string, fg) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      target_x = x + idx

      if target_x < buffer.width do
        Buffer.update_cell(buf, target_x, y, Cell.new(char, fg))
      else
        buf
      end
    end)
  end

  defp buffer_to_iodata(%Buffer{} = buffer), do: Buffer.to_iodata(buffer)
end
