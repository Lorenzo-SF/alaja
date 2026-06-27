defmodule Alaja.Syntax.Special do
  @moduledoc """
  Defines a special tokenization rule for edge cases.

  Tested in priority order before standard keyword/string/number matching.

  ## Fields

    * `pattern` — regex to match at the current position
    * `type` — token type atom to emit (e.g. `:decorator`, `:lifetime`)
    * `priority` — lower values are tested first (default: 50)
    * `multiline` — if true, the pattern can span multiple lines
    * `interpolate` — if true, the matched region contains sub-tokens
      (e.g. `\#{...}`) that should be tokenized recursively
    * `consume` — if true, the matched characters are consumed but not
      emitted as a token (useful for sigil prefixes like `~r` in Elixir)

  ## Examples

      # Python decorator
      %Special{pattern: ~r/@\\w+/, type: :decorator, priority: 10}

      # Rust lifetime (before char literal)
      %Special{pattern: ~r/'[a-z_]\\w*/, type: :lifetime, priority: 10}
  """

  defstruct pattern: nil,
            type: :plain,
            priority: 50,
            multiline: false,
            interpolate: false,
            consume: false
end
