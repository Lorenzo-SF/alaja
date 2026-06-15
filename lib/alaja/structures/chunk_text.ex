defmodule Alaja.Structures.ChunkText do
  @moduledoc """
  Minimal text chunk with formatting.

  Represents a text fragment with its color and effects information.
  This is the basic composition unit for formatted text rendering.

  ## Examples

      iex> ChunkText.new("Hello world")
      %ChunkText{text: "Hello world", color: nil, bg_color: nil, effects: nil}

      iex> ChunkText.new("Hello", color: :red, effects: [:bold])
      %ChunkText{text: "Hello", color: %ColorInfo{...}, effects: %EffectInfo{...}}

  """

  alias Alaja.Structures.EffectInfo
  alias Pote.ColorInfo

  @type t :: %__MODULE__{
          text: String.t(),
          color: ColorInfo.t() | nil,
          bg_color: ColorInfo.t() | nil,
          effects: EffectInfo.t() | nil
        }

  defstruct text: "", color: nil, bg_color: nil, effects: nil

  @doc """
  Creates a new ChunkText.

  ## Parameters

  - `text` - The text to display
  - `opts` - Optional options:
    - `:color` - ColorInfo or convertible value (atom, hex, rgb, etc.)
    - `:bg_color` - Background ColorInfo or convertible value
    - `:effects` - EffectInfo or list of effects

  ## Examples

      iex> ChunkText.new("Hello")
      %ChunkText{text: "Hello"}

      iex> ChunkText.new("Hello", color: :red)
      %ChunkText{text: "Hello", color: %ColorInfo{...}}

      iex> ChunkText.new("Hello", color: "#FF0000", effects: [:bold, :underline])
      %ChunkText{text: "Hello", color: %ColorInfo{...}, effects: %EffectInfo{...}}

  """
  @spec new(String.t(), keyword()) :: t()
  def new(text, opts \\ []) when is_binary(text) do
    %__MODULE__{
      text: text,
      color: parse_color_opt(opts),
      bg_color: parse_bg_color_opt(opts),
      effects: parse_effects_opt(opts)
    }
  end

  defp parse_color_opt(opts) do
    case Keyword.get(opts, :color) do
      nil -> nil
      %ColorInfo{} = ci -> ci
      color -> ColorInfo.new(color)
    end
  end

  defp parse_bg_color_opt(opts) do
    case Keyword.get(opts, :bg_color) do
      nil -> nil
      %ColorInfo{} = ci -> ci
      color -> ColorInfo.new(color)
    end
  end

  defp parse_effects_opt(opts) do
    case Keyword.get(opts, :effects) do
      nil -> nil
      %EffectInfo{} = ei -> ei
      effects -> EffectInfo.new(effects)
    end
  end

  @doc """
  Combines two ChunkTexts (useful for concatenating formatted text).

  The second chunk's properties take precedence over the first's.

  ## Examples

      iex> c1 = ChunkText.new("Hello", color: :red)
      iex> c2 = ChunkText.new(" world", color: :green)
      iex> ChunkText.combine(c1, c2)
      %ChunkText{text: "Hello world", color: %ColorInfo{...}}

  """
  @spec combine(any(), any()) :: any()
  def combine(%__MODULE__{text: t1, color: c1, bg_color: bg1, effects: e1}, %__MODULE__{
        text: t2,
        color: c2,
        bg_color: bg2,
        effects: e2
      }) do
    %__MODULE__{
      text: t1 <> t2,
      color: c2 || c1,
      bg_color: bg2 || bg1,
      effects: EffectInfo.combine(e1 || EffectInfo.new(), e2 || EffectInfo.new())
    }
  end

  @doc """
  Renders the ChunkText with ANSI codes.

  Produces true-color (24-bit) ANSI sequences with effects.
  Always resets formatting after the text.

  ## Examples

      iex> ChunkText.render(ChunkText.new("Hello", color: :red, effects: [:bold]))
      "\\e[38;2;255;0;0m\\e[1mHello\\e[0m"

  """
  @spec render(t()) :: String.t()
  def render(%__MODULE__{text: text, color: color, bg_color: bg_color, effects: effects}) do
    has_invert = effects && (effects.invert || effects.reverse)

    {color_code, effects_code, reset} =
      if has_invert && color do
        render_inverted_mode(color, effects)
      else
        render_normal_mode(color, bg_color, effects)
      end

    "#{color_code}#{effects_code}#{text}#{reset}"
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec render_inverted_mode(ColorInfo.t(), EffectInfo.t()) ::
          {String.t(), String.t(), String.t()}
  defp render_inverted_mode(color, effects) do
    bg_color = ColorInfo.new(color, inverted: true)
    fg_color = EffectInfo.optimal_fg_color(color.rgb)
    fg_color_info = ColorInfo.new(fg_color)

    bg_code = ColorInfo.to_ansi(bg_color)
    fg_code = ColorInfo.to_ansi(fg_color_info)
    effects_code = if effects, do: EffectInfo.to_ansi(effects), else: ""

    {bg_code <> fg_code, effects_code, "\e[0m"}
  end

  @spec render_normal_mode(ColorInfo.t() | nil, ColorInfo.t() | nil, EffectInfo.t() | nil) ::
          {String.t(), String.t(), String.t()}
  defp render_normal_mode(color, bg_color, effects) do
    color_code = if color, do: ColorInfo.to_ansi(color), else: ""
    bg_code = if bg_color, do: ColorInfo.to_ansi(bg_color), else: ""
    effects_code = if effects, do: EffectInfo.to_ansi(effects), else: ""

    reset = if color || bg_color || effects, do: "\e[0m", else: ""

    {bg_code <> color_code, effects_code, reset}
  end
end
