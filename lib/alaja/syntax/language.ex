defmodule Alaja.Syntax.Language do
  @moduledoc """
  Declarative language definition for syntax highlighting.

  Defines what to tokenize (keywords, strings, comments, operators)
  and how to render each token type (colors, effects).

  Colors are resolved through Alaja's theme system (Pote), so values
  can be atoms (`:blue`), hex strings (`"#FF0000"`), or `"theme:key"`.

  ## Example

      %Language{
        name: "Python",
        line_comment: "#",
        strings: [
          %{delim: ~r/\"""/, end: ~r/\"""/, multiline: true, escape: true},
          %{delim: ~r/"/,   end: ~r/"/,   escape: true}
        ],
        number: ~r/\\b\\d[\\d_.]*(e\\d+)?\\b/,
        keywords: MapSet.new(~w(def class if elif else for while return)),
        operators: MapSet.new(["==", "!=", "<=", ">=", "->"]),
        colors: %{
          keyword: {:blue, [:bold]},
          string: {:green, []},
          comment: {:bright_black, [:italic]}
        }
      }
  """

  @type t :: %__MODULE__{
          name: String.t(),
          line_comment: String.t() | nil,
          block_comment: map() | nil,
          strings: [map()],
          number: Regex.t() | nil,
          operators: MapSet.t(),
          keywords: MapSet.t(),
          types: MapSet.t(),
          specials: [map()],
          module_separator: String.t(),
          case_sensitive: boolean(),
          colors: map()
        }

  defstruct name: "unknown",
            line_comment: nil,
            block_comment: nil,
            strings: [],
            number: nil,
            operators: MapSet.new(),
            keywords: MapSet.new(),
            types: MapSet.new(),
            specials: [],
            module_separator: ".",
            case_sensitive: true,
            colors: %{}
end
