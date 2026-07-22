defmodule Alaja.Components.Table.Theme do
  @moduledoc false

  alias Alaja.Structures.ChunkText

  @spec render_formatted(String.t(), term(), list()) :: String.t()
  def render_formatted(text, nil, _effects), do: text

  def render_formatted(text, color, effects) do
    if Alaja.Config.color_enabled?() do
      color_info = Pote.ColorInfo.new(color)

      ChunkText.render(ChunkText.new(text, color: color_info, effects: effects))
    else
      text
    end
  end

  @spec get_column_opts(integer(), term(), term()) :: term()
  def get_column_opts(column_index, column_opts, default_value) do
    case column_opts do
      list when is_list(list) and length(list) == 1 -> hd(list)
      list when is_list(list) -> Enum.at(list, column_index, default_value)
      value -> value
    end
  end
end
