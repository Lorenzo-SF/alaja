defmodule Alaja.Components.Table do
  @moduledoc """
  Component for rendering formatted tables with advanced layout.

  Supports tables with:
  - Optional headers separated from rows
  - Per-cell, per-row, or per-column formatting
  - Per-cell and full-table alignment
  - Colors and effects
  - Customizable borders (normal, rounded, double, none, custom)
  - Configurable padding
  - Border formatting (color, effects)
  - Full-table alignment (left, center, right)

  ## Options

  ### Data
  - `:headers` — List of headers (if not included in data)
  - `:rows` — List of rows (if not included in data)

  ### Header Formatting
  - `:headers_color` — Header color (atom, hex, or list per column)
  - `:headers_effects` — Header effects (list, or list of lists per column)
  - `:headers_align` — Header alignment (:left, :center, :right, or list)

  ### Row Formatting
  - `:rows_color` — Row color (atom, hex, or list per column)
  - `:rows_effects` — Row effects (list, or list of lists per column)
  - `:rows_align` — Row alignment (:left, :center, :right, or list)

  ### Specific Row Formatting
  - `:rows_0_color` — Row 0 color (atom, hex, or list per column)
  - `:rows_0_effects` — Row 0 effects
  - `:rows_0_align` — Row 0 alignment (:left, :center, :right, or list)
  - (Repeat for rows_1_, rows_2_, etc.)

  ### Border Formatting
  - `:border_color` — Border color
  - `:border_effects` — Border effects

  ### Table Style
  - `:table_border` — Border style (:normal, :rounded, :double, :none, :custom)
  - `:table_border_custom` — Map with custom border characters
  - `:padding` — Inner cell padding (default: 1)
  - `:table_align` — Full table alignment (:left, :center, :right)

  ## Examples

      # Headers separated from rows
      Alaja.Components.Table.print(
        headers: ["ID", "Name", "Email"],
        rows: [
          ["1", "Jake", "jake@nypd.com"],
          ["2", "Rosa", "rosa@nypd.com"]
        ],
        headers_color: :cyan,
        headers_effects: [:bold],
        rows_color: :white,
        table_border: :rounded,
        padding: 1
      )

      # Per-column formatting
      Alaja.Components.Table.print(
        headers: ["Name", "Age", "City"],
        rows: [["Jake", "35", "NYC"]],
        headers_color: [:cyan, :yellow, :magenta],
        headers_align: [:center, :right, :left]
      )

      # Specific row formatting
      Alaja.Components.Table.print(
        headers: ["Service", "Status"],
        rows: [["td-ai", "OK"], ["td-auth", "ERROR"]],
        rows_0_color: [:white, :green],
        rows_1_color: [:white, :red]
      )

      # Without headers
      Alaja.Components.Table.print(
        rows: [
          ["1", "Jake", "jake@nypd.com"],
          ["2", "Rosa", "rosa@nypd.com"]
        ],
        table_border: :double
      )

      # Border formatting
      Alaja.Components.Table.print(
        headers: ["ID", "Name"],
        rows: [["1", "Jake"]],
        border_color: :cyan,
        border_effects: [:bold]
      )

      # Table centered in terminal
      Alaja.Components.Table.print(
        headers: ["A", "B"],
        rows: [["1", "2"]],
        table_align: :center,
        table_border: :rounded
      )

  """

  alias Alaja.Buffer
  alias Alaja.Components.Table.{Builder, Calculator, Renderer}

  @type border_style :: :normal | :rounded | :double | :none | :custom
  @type align :: :left | :center | :right
  @type color :: atom() | String.t() | {integer(), integer(), integer()}
  @type effects :: list(atom())

  defmodule Config do
    @moduledoc false

    @type t :: %__MODULE__{
            border_style: atom(),
            border_chars: map() | nil,
            padding: non_neg_integer(),
            table_align: atom(),
            border_color: term(),
            border_effects: list(),
            offset_spaces: non_neg_integer(),
            offset_str: String.t(),
            horizontal_segments: list(),
            rendered_vertical: String.t()
          }

    defstruct [
      :border_style,
      :border_chars,
      :padding,
      :table_align,
      :border_color,
      :border_effects,
      :offset_spaces,
      :offset_str,
      :horizontal_segments,
      :rendered_vertical
    ]
  end

  @doc """
  Prints a table to the terminal.

  If `:page_size` is set, enables interactive pagination:
  - `n` / `→` — next page
  - `p` / `←` — previous page
  - `g` — go to page (prompts for number)
  - `f` / `l` — first / last page
  - `q` / `Esc` — quit
  """
  @spec print(list() | keyword(), keyword()) :: :ok
  def print(data, opts \\ [])

  def print(data, opts) when is_list(data) do
    if Keyword.keyword?(data) do
      headers = Keyword.get(data, :headers)
      rows = Keyword.get(data, :rows, [])
      table_opts = Keyword.drop(data, [:headers, :rows])
      merged_opts = Keyword.merge(table_opts, opts)
      Builder.print_with_headers(headers, rows, merged_opts)
    else
      case data do
        [] -> :ok
        [headers | rows] -> Builder.print_with_headers(headers, rows, opts)
      end
    end
  end

  @doc """
  Renders a table to an `Alaja.Buffer.t/0` without printing.

  This is the Cell-engine render. Returns a composable `Buffer` that
  can be overlaid on other buffers or passed to `Alaja.Components.Box`.

  See `render_buffer/2` for the implementation.
  """
  @spec render(list() | keyword(), keyword()) :: Buffer.t()
  def render(data, opts \\ [])

  def render(data, opts) do
    render_buffer(data, opts)
  end

  @doc false
  @spec render_iodata(list() | keyword(), keyword()) :: String.t()
  def render_iodata(data, opts \\ []) do
    {headers, rows} = Builder.extract_headers_rows(data)
    merged_opts = Keyword.merge(opts, Builder.extract_table_opts(data))
    {headers, rows} = Builder.normalize_data(headers, rows)
    column_widths = Calculator.calculate_column_widths([headers | rows])
    config = Builder.build_config(merged_opts, column_widths)
    rendered = Renderer.build_table_string(headers, rows, column_widths, config, merged_opts)
    IO.iodata_to_binary(rendered)
  end

  @doc """
  Renders a table into an `Alaja.Buffer.t/0` (Cell engine, v0.3.0).

  Supports column widths, alignment, header/row colors, and the same
  border styles as `render/2`. Pagination is NOT supported here — for
  interactive tables, use `print/2`.

  ## Options

  Same as `render/2` but limited to layout-level options. Per-cell /
  per-row / per-column formatting is supported via the same keywords.
  """
  @spec render_buffer(list(), keyword()) :: Buffer.t()
  def render_buffer(data, opts \\ [])

  def render_buffer([headers | rows], opts) when is_list(headers) do
    {headers, rows} = Builder.normalize_data(headers, rows)
    column_widths = Calculator.calculate_column_widths([headers | rows])
    config = Builder.build_config(opts, column_widths)
    Renderer.do_render_buffer(headers, rows, column_widths, config, opts)
  end

  def render_buffer(data, opts) do
    headers = Keyword.get(data, :headers)
    rows = Keyword.get(data, :rows, [])
    table_opts = Keyword.drop(data, [:headers, :rows])
    merged = Keyword.merge(opts, table_opts)
    {headers, rows} = Builder.normalize_data(headers || [], rows)
    column_widths = Calculator.calculate_column_widths([headers | rows])
    config = Builder.build_config(merged, column_widths)
    Renderer.do_render_buffer(headers, rows, column_widths, config, merged)
  end
end
