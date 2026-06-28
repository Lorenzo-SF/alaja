defmodule Alaja.Syntax.Theme do
  @moduledoc """
  Global syntax highlighting theme.

  Maps token types to `{color, [effects]}` pairs. Colors are resolved
  through Pote's theme system, so they accept atoms, hex strings, or
  `"theme:<key>"` strings.

  When rendering, the lookup order is:

    1. Language-level colors (`lang.colors`)
    2. Global `Syntax.Theme`
    3. Hardcoded defaults

  ## Example

      %Theme{
        name: "dracula",
        colors: %{
          keyword:  {:pink,    [:bold]},
          string:   {:yellow,  []},
          comment:  {:cyan,    [:italic]},
          number:   {:purple,  []}
        }
      }
  """

  defstruct name: "default",
            colors: %{}

  @defaults %{
    keyword: {:blue, [:bold]},
    string: {:green, []},
    comment: {:bright_black, [:italic]},
    number: {:cyan, []},
    operator: {:white, []},
    atom: {:yellow, []},
    module: {:magenta, []},
    type: {:cyan, []},
    builtin: {:cyan, []},
    macro: {:magenta, [:bold]},
    variable: {:red, []},
    lifetime: {:cyan, [:italic]},
    field: {:yellow, []},
    plain: {:white, []},
    decorator: {:yellow, []}
  }

  @doc "Returns the default theme with hardcoded fallback colors."
  def default do
    %__MODULE__{name: "default", colors: @defaults}
  end

  @doc "Resolves a token type's color and effects through a theme chain."
  def resolve(token_type, lang_colors, global_theme) do
    Map.get(lang_colors, token_type) ||
      Map.get(global_theme.colors, token_type) ||
      Map.get(@defaults, token_type) ||
      {:white, []}
  end
end
