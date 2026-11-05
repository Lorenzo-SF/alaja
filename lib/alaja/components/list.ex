defmodule Alaja.Components.List do
  @moduledoc """
  Styled bullet list rendering.

  Provides functions to build formatted lists with optional headers,
  colors, and alignment (left, center, right).

  ## Usage

      # Simple list
      result = Alaja.Components.List.build(["Item 1", "Item 2", "Item 3"])

      # With header and color
      result = Alaja.Components.List.build(["Start", "Stop", "Restart"],
        header: "Options:", color: {0, 180, 216})

      # Centered
      result = Alaja.Components.List.build(["Alpha", "Beta", "Gamma"],
        align: :center, color: {255, 255, 0})
  """

  @doc """
  Builds a formatted list string.

  Returns the list as an ANSI-string (with color escape codes if
  `:color` is set) ready for printing.

  ## Options

    * `:header` — optional header/title string
    * `:color` — RGB tuple for bullet and text color
    * `:align` — `:left`, `:center`, or `:right`
  """
  @spec build([String.t()], keyword()) :: IO.chardata()
  def build(items, opts \\ []) do
    header = Keyword.get(opts, :header)
    color = Keyword.get(opts, :color)
    align = Keyword.get(opts, :align, :left)

    case header do
      nil -> build_items(items, color, align)
      h -> build_with_header(h, items, color, align)
    end
  end

  @doc """
  Builds a list with a header line.

  The header is rendered as a plain line above the bullet items.
  """
  @spec build_with_header(
          String.t(),
          [String.t()],
          {integer(), integer(), integer()} | nil,
          atom()
        ) :: IO.chardata()
  def build_with_header(header, items, color, align \\ :left) do
    header_line = "  #{header}"
    item_lines = Enum.map_join(items, "\n", &format_item(&1, color, align))
    [header_line, "\n", item_lines, "\n"]
  end

  @doc """
  Builds a list without a header.
  """
  @spec build_items([String.t()], {integer(), integer(), integer()} | nil, atom()) ::
          IO.chardata()
  def build_items(items, color, align \\ :left) do
    items
    |> Enum.map_join("\n", &format_item(&1, color, align))
    |> then(&[&1, "\n"])
  end

  @doc """
  Formats a single list item with bullet point, optional color, and alignment.

  The bullet character is `•`. When `color` is set, both the bullet and
  text are rendered in that color using ANSI escapes.
  """
  @spec format_item(String.t(), {integer(), integer(), integer()} | nil, atom()) :: String.t()
  def format_item(item, color, align \\ :left)

  def format_item(item, nil, align) do
    apply_align("  • #{item}", align)
  end

  def format_item(item, {r, g, b}, align) do
    apply_align(
      "#{Pote.Orchestrator.to_ansi({r, g, b})}  • #{item}#{Alaja.ANSI.reset_attributes()}",
      align
    )
  end

  @doc """
  Applies alignment to a line.

  For `:left`, returns the line unchanged. For `:center` and `:right`,
  pads with spaces based on terminal width. ANSI codes are stripped
  before measuring visible length.
  """
  @spec apply_align(String.t(), atom()) :: String.t()
  def apply_align(line, :left), do: line

  def apply_align(line, align) when align in [:center, :right] do
    visible_len = line |> String.replace(~r/\x1b\[[0-9;]*m/, "") |> String.length()
    term_width = term_width()

    padding =
      case align do
        :center -> max(0, div(term_width - visible_len, 2))
        :right -> max(0, term_width - visible_len)
      end

    String.duplicate(" ", padding) <> line
  end

  def apply_align(line, _), do: line

  @doc """
  Returns the terminal width, defaulting to 80 if unknown.
  """
  @spec term_width() :: pos_integer()
  def term_width do
    case :io.columns() do
      {:ok, w} -> w
      _ -> 80
    end
  end
end
