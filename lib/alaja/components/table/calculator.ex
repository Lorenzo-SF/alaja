defmodule Alaja.Components.Table.Calculator do
  @moduledoc false

  @ansi_regex ~r/\x1b\[[0-9;]*m/

  @spec calculate_column_widths(list()) :: list(integer())
  def calculate_column_widths(data) do
    valid_data = Enum.reject(data, &(&1 == [] || !&1))

    if valid_data == [] do
      []
    else
      max_columns = Enum.map(valid_data, &length/1) |> Enum.max(fn -> 0 end)

      Enum.map(0..(max_columns - 1), fn col_index ->
        calculate_max_column_width(valid_data, col_index)
      end)
    end
  end

  @spec calculate_max_column_width(list(), integer()) :: integer()
  def calculate_max_column_width(data, col_index) do
    data
    |> Enum.map(fn row ->
      row |> Enum.at(col_index, "") |> to_string() |> visible_length()
    end)
    |> Enum.max(fn -> 0 end)
  end

  @spec calculate_table_width(list(integer()), integer()) :: integer()
  def calculate_table_width(column_widths, padding) do
    Enum.sum(column_widths) + length(column_widths) * (padding * 2 + 2) + 1
  end

  @spec get_table_offset(integer(), :left | :center | :right) :: integer()
  def get_table_offset(table_width, alignment) do
    {terminal_width, _} = Alaja.Terminal.size()

    case alignment do
      :center -> div(max(terminal_width - table_width, 0), 2)
      :right -> max(terminal_width - table_width, 0)
      _ -> 0
    end
  end

  @spec visible_length(String.t()) :: integer()
  def visible_length(text) do
    stripped = text |> String.replace(@ansi_regex, "")
    Alaja.Text.width(stripped)
  end

  @spec pad_visible(String.t(), integer()) :: String.t()
  def pad_visible(text, width) do
    visible = visible_length(text)
    padding = max(0, width - visible)
    text <> String.duplicate(" ", padding)
  end

  @spec pad_visible_leading(String.t(), integer()) :: String.t()
  def pad_visible_leading(text, width) do
    visible = visible_length(text)
    padding = max(0, width - visible)
    String.duplicate(" ", padding) <> text
  end

  @spec center_text(String.t(), integer()) :: String.t()
  def center_text(text, width) do
    visible = visible_length(text)

    if visible >= width do
      text
    else
      total_pad = width - visible
      left_pad = div(total_pad, 2)
      right_pad = total_pad - left_pad
      String.duplicate(" ", left_pad) <> text <> String.duplicate(" ", right_pad)
    end
  end

  @spec apply_alignment(String.t(), :left | :center | :right, integer(), integer()) :: String.t()
  def apply_alignment(text, :left, width, padding) do
    total_left = 2 + padding
    total_right = 2 + padding
    inner = pad_visible(text, width)
    String.duplicate(" ", total_left) <> inner <> String.duplicate(" ", total_right)
  end

  def apply_alignment(text, :center, width, padding) do
    total_left = 2 + padding
    total_right = 2 + padding
    inner = center_text(text, width)
    String.duplicate(" ", total_left) <> inner <> String.duplicate(" ", total_right)
  end

  def apply_alignment(text, :right, width, padding) do
    total_left = 2 + padding
    total_right = 2 + padding
    inner = pad_visible_leading(text, width)
    String.duplicate(" ", total_left) <> inner <> String.duplicate(" ", total_right)
  end

  def apply_alignment(text, _, width, padding) do
    apply_alignment(text, :left, width, padding)
  end
end
