defmodule Alaja.Syntax.Renderer do
  @moduledoc """
  Converts token lists to ANSI-formatted terminal output.

  Uses `ChunkText` as intermediate representation so colors and effects
  are resolved through Pote's theme system — same pipeline that
  `Alaja.print_success`, `Alaja.Components.Table` etc. already use.
  """

  alias Alaja.Structures.ChunkText
  alias Alaja.Syntax.Theme

  @doc """
  Renders a token list into display-ready `{color, text}` tuples.

  Each tuple's color is an ANSI color string resolved through
  the theme chain:
    1. Language-level colors (`lang.colors`)
    2. Global syntax theme
    3. Hardcoded defaults

  ## Examples

      iex> lang = %Alaja.Syntax.Language{
      ...>   name: "test",
      ...>   colors: %{keyword: {:blue, [:bold]}}
      ...> }
      iex> Renderer.render([{:keyword, "def"}, {:plain, " x"}], lang)
      [{"blue", "def"}, {"white", " x"}]
  """
  @spec render([{atom(), String.t()}], Alaja.Syntax.Language.t(), Theme.t() | nil) :: [
          {String.t(), String.t()}
        ]
  def render(tokens, lang, global_theme \\ nil) do
    theme = global_theme || Theme.default()

    Enum.map(tokens, fn {type, text} ->
      {color_name, _effects} = Theme.resolve(type, lang.colors, theme)
      {to_string(color_name), text}
    end)
  end

  @doc """
  Renders tokens to ANSI escape sequences ready for terminal output.

  Uses `ChunkText.render/1` under the hood, which resolves colors
  through Pote's resolver bridge (supports atoms, hex, `"theme:key"`,
  etc.) and applies effects (bold, italic, etc.).
  """
  @spec render_ansi([{atom(), String.t()}], Alaja.Syntax.Language.t(), Theme.t() | nil) ::
          IO.iodata()
  def render_ansi(tokens, lang, global_theme \\ nil) do
    theme = global_theme || Theme.default()

    tokens
    |> Enum.map(fn {type, text} ->
      {color_atom, effects} = Theme.resolve(type, lang.colors, theme)
      ChunkText.new(text, color: color_atom, effects: effects)
    end)
    |> Enum.map_join(&ChunkText.render/1)
  end

  @doc """
  Renders token list as a flat string (no ANSI escapes).
  Useful for testing or non-terminal output.
  """
  @spec render_plain([{atom(), String.t()}]) :: String.t()
  def render_plain(tokens) do
    Enum.map_join(tokens, fn {_type, text} -> text end)
  end
end
