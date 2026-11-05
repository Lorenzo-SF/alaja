defmodule Alaja.Components.ColorWheel.Harmonies do
  @moduledoc false

  alias Pote
  alias Pote.{Converters, Harmonies}

  @type rgb :: Pote.rgb()

  @doc """
  Computes the harmony colors for a given type and base RGB.
  """
  @spec compute_harmony(rgb(), atom()) :: [rgb()]
  def compute_harmony(rgb, harmony_type) do
    case harmony_type do
      :complementary -> Harmonies.complementary(rgb)
      :analogous -> Harmonies.analogous(rgb)
      :triad -> Harmonies.triad(rgb)
      :square -> Harmonies.square(rgb)
      :monochromatic -> Harmonies.monochromatic(rgb)
      :split_complementary -> Harmonies.split_complementary(rgb)
      :compound -> Harmonies.compound(rgb)
      _ -> []
    end
  end

  @doc """
  Extracts HSL hue angles from a list of RGB tuples.
  """
  @spec extract_angles([rgb()]) :: [number()]
  def extract_angles(rgbs) do
    Enum.map(rgbs, fn rgb ->
      {h, _s, _l} = Converters.rgb_to_hsl(rgb)
      h
    end)
  end

  @doc """
  Returns the Spanish display name for a harmony type.
  """
  @spec harmony_display_name(atom()) :: String.t()
  def harmony_display_name(:complementary), do: "COMPLEMENTARIA"
  def harmony_display_name(:analogous), do: "ANÁLOGA"
  def harmony_display_name(:triad), do: "TRÍADA"
  def harmony_display_name(:square), do: "CUADRADA"
  def harmony_display_name(:monochromatic), do: "MONOCROMÁTICA"
  def harmony_display_name(:split_complementary), do: "SPLIT-COMPLEMENTARIA"
  def harmony_display_name(:compound), do: "COMPUESTA"
  def harmony_display_name(_), do: "ARMONÍA"
end
