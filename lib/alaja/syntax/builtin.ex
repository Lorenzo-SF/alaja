defmodule Alaja.Syntax.Builtin do
  @moduledoc """
  Built-in inline tokenizers for common languages: Elixir, JSON, Markdown.

  These are kept for backward compatibility and fast-path CLI rendering.
  For full language support (Python, Rust, Go, etc.) use
  `Alaja.Syntax.register_language/2` with `Alaja.Syntax.Engine`.
  """

  @elixir_keywords ~w(def defmodule defp do end case cond if else when with fn
                       use import alias require receive send raise try catch
                       after rescue throw for while return)

  @doc """
  Tokenizes Elixir source code.
  """
  @spec tokenize_elixir(String.t()) :: [{atom(), String.t()}]
  def tokenize_elixir(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(&tokenize_elixir_line/1)
  end

  defp tokenize_elixir_line(line) do
    if String.starts_with?(String.trim_leading(line), "#") do
      [{:comment, line}]
    else
      tokenize_elixir_parts(line, [])
    end
  end

  defp tokenize_elixir_parts("", acc), do: Enum.reverse(acc)

  defp tokenize_elixir_parts(line, acc) do
    {token, rest} = take_next_token(line)

    {type, text} =
      case token do
        "" -> {:plain, rest}
        text -> classify_elixir_token(text)
      end

    if rest == "" or rest == line do
      Enum.reverse([{type, text} | acc])
    else
      tokenize_elixir_parts(rest, [{type, text} | acc])
    end
  end

  defp classify_elixir_token(text) do
    cond do
      String.starts_with?(text, "\"") -> {:string, text}
      atom_token?(text) -> {:atom, text}
      String.starts_with?(text, "#") -> {:comment, text}
      text in @elixir_keywords -> {:keyword, text}
      module_token?(text) -> {:module, text}
      number_token?(text) -> {:number, text}
      true -> {:plain, text}
    end
  end

  defp atom_token?(text),
    do: String.starts_with?(text, ":") and not String.starts_with?(text, "::")

  defp module_token?(text), do: Regex.match?(~r/^[A-Z]/, text) and String.contains?(text, ".")
  defp number_token?(text), do: Regex.match?(~r/^-?\d+(\.\d+)?$/, text)

  defp take_next_token(line) do
    case Regex.run(
           ~r/^(\s+|[A-Za-z_][A-Za-z0-9_]*[!?]?|"[^"]*"|:[A-Za-z_][A-Za-z0-9_]*[!?]?|#[^\n]*|-?\d+(\.\d+)?|.)/,
           line
         ) do
      [match, token] -> {token, String.replace_prefix(line, match, "")}
      _ -> {"", line}
    end
  end

  @doc """
  Tokenizes JSON source code.
  """
  @spec tokenize_json(String.t()) :: [{atom(), String.t()}]
  def tokenize_json(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(&tokenize_json_line/1)
  end

  defp tokenize_json_line(line) do
    line
    |> String.split(~r/("[^"]*"|\d+|true|false|null|[{}\[\],:])/,
      include_captures: true,
      trim: true
    )
    |> Enum.map(fn token ->
      cond do
        String.starts_with?(token, "\"") -> {:string, token}
        token in ["true", "false", "null"] -> {:keyword, token}
        token in ["{", "}", "[", "]", ",", ":"] -> {:operator, token}
        Regex.match?(~r/^\d+(\.\d+)?$/, token) -> {:number, token}
        true -> {:plain, token}
      end
    end)
  end

  @doc """
  Tokenizes Markdown source code.
  """
  @spec tokenize_markdown(String.t()) :: [{atom(), String.t()}]
  def tokenize_markdown(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(&tokenize_markdown_line/1)
  end

  defp tokenize_markdown_line(line) do
    cond do
      Regex.match?(~r/^\#{1,6}\s+/, line) -> [{:keyword, line}]
      Regex.match?(~r/^\*\*[^*]+\*\*$/, String.trim(line)) -> [{:keyword, line}]
      Regex.match?(~r/^\*[^*]+\*$/, String.trim(line)) -> [{:keyword, line}]
      String.contains?(line, "`") -> [{:string, line}]
      String.contains?(line, "](") -> [{:module, line}]
      true -> [{:plain, line}]
    end
  end

  # ── Color mapping (built-in defaults) ─────────────────────────────────

  @doc "Maps a token type atom to an ANSI color name (string)."
  @spec color_for(atom()) :: String.t()
  def color_for(:keyword), do: "blue"
  def color_for(:string), do: "green"
  def color_for(:comment), do: "gray"
  def color_for(:number), do: "cyan"
  def color_for(:operator), do: "white"
  def color_for(:atom), do: "yellow"
  def color_for(:module), do: "magenta"
  def color_for(:plain), do: "white"
  def color_for(_), do: "white"

  @doc "Maps a token type atom to an atom colour name (for buffer pipeline)."
  @spec color_for_atom(atom()) :: atom()
  def color_for_atom(:keyword), do: :blue
  def color_for_atom(:string), do: :green
  def color_for_atom(:comment), do: :gray
  def color_for_atom(:number), do: :cyan
  def color_for_atom(:operator), do: :white
  def color_for_atom(:atom), do: :yellow
  def color_for_atom(:module), do: :magenta
  def color_for_atom(:plain), do: :white
  def color_for_atom(_), do: :white

  @doc """
  ANSI 16-colour palette for the buffer pipeline — maps atoms to
  `{r, g, b}` tuples. Bright variants use the half-bright split.
  Unknown atoms fall back to white.
  """
  @spec ansi_16_colors() :: %{atom() => {0..255, 0..255, 0..255}}
  def ansi_16_colors do
    %{
      black: {0, 0, 0},
      red: {170, 0, 0},
      green: {0, 170, 0},
      yellow: {170, 85, 0},
      blue: {0, 0, 170},
      magenta: {170, 0, 170},
      cyan: {0, 170, 170},
      white: {170, 170, 170},
      default: {255, 255, 255},
      bright_black: {85, 85, 85},
      gray: {85, 85, 85},
      grey: {85, 85, 85},
      bright_red: {255, 85, 85},
      bright_green: {85, 255, 85},
      bright_yellow: {255, 255, 85},
      bright_blue: {85, 85, 255},
      bright_magenta: {255, 85, 255},
      bright_cyan: {85, 255, 255},
      bright_white: {255, 255, 255}
    }
  end
end
