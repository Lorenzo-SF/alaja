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
  @default_item_color {0, 180, 216}
  @default_current_color {255, 255, 255}
  @default_separator_color {100, 100, 100}

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
    sep_color = Keyword.get(opts, :separator_color, @default_separator_color)

    sep_str = " #{separator} "
    last_idx = length(items) - 1

    total_w =
      items
      |> Enum.with_index()
      |> Enum.reduce(0, fn {item, idx}, acc ->
        acc + String.length(item) + if(idx < last_idx, do: String.length(sep_str), else: 0)
      end)

    buffer = Buffer.new(total_w, 1)
    x = 0

    items
    |> Enum.with_index()
    |> Enum.reduce({buffer, x}, fn {item, idx}, {buf, cx} ->
      color = if idx == last_idx, do: current_color, else: item_color
      buf = write_string(buf, cx, 0, item, color)

      if idx < last_idx do
        {write_string(buf, cx + String.length(item), 0, sep_str, sep_color),
         cx + String.length(item) + String.length(sep_str)}
      else
        {buf, cx + String.length(item)}
      end
    end)
    |> elem(0)
  end

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
  defp buffer_to_iodata(other), do: other
end
