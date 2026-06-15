defmodule Alaja.Structures.EffectInfo do
  @moduledoc """
  Structure that defines text effects applicable in terminal.

  Represents a collection of visual effects (bold, italic, underline, etc.)
  that can be applied to text when rendering to terminal.

  ## Examples

      iex> EffectInfo.new(:bold)
      %EffectInfo{bold: true, dim: false, ...}

      iex> EffectInfo.new([:bold, :underline])
      %EffectInfo{bold: true, underline: true, ...}

      iex> EffectInfo.to_ansi(EffectInfo.new([:bold, :italic]))
      "\\e[1;3m"

  """

  @type t :: %__MODULE__{
          bold: boolean(),
          dim: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          invert: boolean(),
          hidden: boolean(),
          strikethrough: boolean(),
          link: String.t() | nil
        }

  defstruct bold: false,
            dim: false,
            italic: false,
            underline: false,
            blink: false,
            reverse: false,
            invert: false,
            hidden: false,
            strikethrough: false,
            link: nil

  @doc """
  Creates a new empty EffectInfo structure.

  ## Examples

      iex> EffectInfo.new()
      %EffectInfo{bold: false, dim: false, ...}

  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Creates a new EffectInfo from various inputs.

  ## Parameters

  - `effect` - Can be:
    - An atom (`:bold`, `:italic`, etc.)
    - A list of atoms
    - A URL string (creates link effect)
    - An existing EffectInfo struct
    - A map with effect fields

  ## Examples

      iex> EffectInfo.new(:bold)
      %EffectInfo{bold: true, ...}

      iex> EffectInfo.new([:bold, :underline])
      %EffectInfo{bold: true, underline: true, ...}

      iex> EffectInfo.new("https://example.com")
      %EffectInfo{link: "https://example.com"}

  """
  @spec new(atom() | [atom()] | String.t() | t() | map()) :: t()
  def new(effect) when is_atom(effect), do: apply_effect(%__MODULE__{}, effect)

  def new(effects) when is_list(effects) do
    Enum.reduce(effects, %__MODULE__{}, fn effect, acc -> apply_effect(acc, effect) end)
  end

  def new(%{link: url}) when is_binary(url), do: %__MODULE__{link: url}
  def new(url) when is_binary(url), do: %__MODULE__{link: url}
  def new(%__MODULE__{} = effect_info), do: effect_info
  def new(%{} = map), do: struct(__MODULE__, map)

  @doc """
  Combines two EffectInfo structures.

  Effects are combined using OR logic - if either has an effect enabled,
  the result will have it enabled.

  ## Examples

      iex> e1 = EffectInfo.new(:bold)
      iex> e2 = EffectInfo.new(:italic)
      iex> EffectInfo.combine(e1, e2)
      %EffectInfo{bold: true, italic: true, ...}

  """
  @spec combine(any(), any()) :: any()
  def combine(%__MODULE__{} = e1, %__MODULE__{} = e2) do
    %__MODULE__{
      bold: combine_bool(e1.bold, e2.bold),
      dim: combine_bool(e1.dim, e2.dim),
      italic: combine_bool(e1.italic, e2.italic),
      underline: combine_bool(e1.underline, e2.underline),
      blink: combine_bool(e1.blink, e2.blink),
      reverse: combine_bool(e1.reverse, e2.reverse),
      invert: combine_bool(e1.invert, e2.invert),
      hidden: combine_bool(e1.hidden, e2.hidden),
      strikethrough: combine_bool(e1.strikethrough, e2.strikethrough),
      link: combine_bool(e1.link, e2.link)
    }
  end

  @doc """
  Converts EffectInfo to ANSI escape codes.

  ## Examples

      iex> EffectInfo.to_ansi(EffectInfo.new([:bold, :underline]))
      "\\e[1;4m"

  """
  @spec to_ansi(t()) :: String.t()
  def to_ansi(%__MODULE__{} = ei) do
    codes =
      Enum.reduce(_ansi_codes(), [], fn {field, code}, acc ->
        if Map.get(ei, field), do: [code | acc], else: acc
      end)

    if codes == [], do: "", else: "\e[#{Enum.join(codes, ";")}m"
  end

  defp _ansi_codes do
    [
      {:bold, "1"},
      {:dim, "2"},
      {:italic, "3"},
      {:underline, "4"},
      {:blink, "5"},
      {:reverse, "7"},
      {:invert, "7"},
      {:hidden, "8"},
      {:strikethrough, "9"}
    ]
    |> Enum.sort_by(fn {field, _} -> field end)
  end

  @doc """
  Calculates the optimal foreground color for a given background color.

  Uses brightness (luminance) to determine whether to use white or black
  for best contrast.

  ## Examples

      iex> EffectInfo.optimal_fg_color({255, 255, 255})
      {0, 0, 0}

      iex> EffectInfo.optimal_fg_color({0, 0, 0})
      {255, 255, 255}

  """
  @spec optimal_fg_color({integer(), integer(), integer()}) :: {integer(), integer(), integer()}
  def optimal_fg_color({r, g, b}) do
    brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    if brightness > 0.5 do
      {0, 0, 0}
    else
      {255, 255, 255}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec apply_effect(t(), atom()) :: t()
  defp apply_effect(ei, :bold), do: %{ei | bold: true}
  defp apply_effect(ei, :dim), do: %{ei | dim: true}
  defp apply_effect(ei, :italic), do: %{ei | italic: true}
  defp apply_effect(ei, :underline), do: %{ei | underline: true}
  defp apply_effect(ei, :blink), do: %{ei | blink: true}
  defp apply_effect(ei, :reverse), do: %{ei | reverse: true}
  defp apply_effect(ei, :invert), do: %{ei | invert: true}
  defp apply_effect(ei, :hidden), do: %{ei | hidden: true}
  defp apply_effect(ei, :strikethrough), do: %{ei | strikethrough: true}
  defp apply_effect(ei, _), do: ei

  @spec combine_bool(boolean(), boolean()) :: boolean()
  defp combine_bool(a, b), do: a || b
end
