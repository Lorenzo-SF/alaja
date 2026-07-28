defmodule Alaja.Buffer.Position do
  @moduledoc false

  alias Alaja.Buffer

  @doc false
  @spec valid_coord?(Buffer.t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def valid_coord?(%Buffer{width: w, height: h}, x, y) do
    x >= 0 and x < w and y >= 0 and y < h
  end

  @doc false
  @spec with_offset(Buffer.t(), non_neg_integer(), non_neg_integer()) :: Buffer.t()
  def with_offset(%Buffer{} = buffer, x, y) when x >= 0 and y >= 0 do
    %{buffer | offset_x: x, offset_y: y}
  end

  @doc false
  @spec positioned?(Buffer.t()) :: boolean()
  def positioned?(%Buffer{offset_x: 0, offset_y: 0}), do: false
  def positioned?(%Buffer{}), do: true
end
