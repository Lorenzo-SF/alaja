defmodule Alaja.Components.Breadcrumbs do
  @moduledoc """
  Static breadcrumb navigation component for terminal output.

  Renders a path-like list of items with a separator.

  ## Usage

      iex> Alaja.Components.Breadcrumbs.print(["Home", "Projects", "Alaja"])
      # Home > Projects > Alaja
  """

  @default_separator "›"
  @default_item_color {0, 180, 216}
  @default_current_color {255, 255, 255}
  @default_separator_color {100, 100, 100}

  @doc """
  Prints breadcrumbs to stdout.

  ## Options

  - `:separator` - String between items (default: `"›"`)
  - `:item_color` - RGB for non-current items (default: cyan)
  - `:current_color` - RGB for the last (current) item (default: white)
  - `:separator_color` - RGB for separator (default: gray)
  """
  @spec print([String.t()], keyword()) :: :ok
  def print(items, opts \\ []) do
    items |> render(opts) |> IO.write()
    IO.puts("")
  end

  @doc """
  Renders breadcrumbs to iodata without printing.
  """
  @spec render([String.t()], keyword()) :: iodata()
  def render([], _opts), do: []

  def render(items, opts) do
    separator = Keyword.get(opts, :separator, @default_separator)
    {ir, ig, ib} = Keyword.get(opts, :item_color, @default_item_color)
    {cr, cg, cb} = Keyword.get(opts, :current_color, @default_current_color)
    {sr, sg, sb} = Keyword.get(opts, :separator_color, @default_separator_color)

    last_idx = length(items) - 1

    items
    |> Enum.with_index()
    |> Enum.map(fn {item, idx} ->
      color =
        if idx == last_idx do
          Pote.Orchestrator.to_ansi({cr, cg, cb})
        else
          Pote.Orchestrator.to_ansi({ir, ig, ib})
        end

      sep =
        if idx < last_idx do
          [
            Pote.Orchestrator.to_ansi({sr, sg, sb}),
            " #{separator} ",
            Alaja.ANSI.reset_attributes()
          ]
        else
          []
        end

      [color, item, Alaja.ANSI.reset_attributes(), sep]
    end)
  end
end
