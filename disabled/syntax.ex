defmodule Alaja.Syntax do
  @moduledoc """
  Syntax highlighting dinámico para lenguajes de programación.

  Detecta automáticamente el tipo de archivo por extensión y aplica
  el highlighting correspondiente.

  ## Uso

      # Detección automática por path
      Syntax.highlight_file("/path/to/file.ex", theme)

      # Detección automática por contenido
      Syntax.highlight_content(content, :elixir, theme)

      # Highlight de una línea específica
      Syntax.highlight_line(line, :elixir, theme)

  ## Lenguajes Soportados

    * `:elixir` - Archivos .ex, .exs
    * `:json` - Archivos .json
    * `:markdown` - Archivos .md
    * `:text` - Texto plano (sin highlighting)

  """

  alias Alaja.Cell
  alias Alaja.Syntax.Rules

  @type file_type ::
          :elixir
          | :erlang
          | :python
          | :typescript
          | :javascript
          | :tsx
          | :rust
          | :go
          | :java
          | :kotlin
          | :csharp
          | :c
          | :cpp
          | :php
          | :ruby
          | :swift
          | :dart
          | :scala
          | :lua
          | :bash
          | :r
          | :haskell
          | :clojure
          | :zig
          | :nim
          | :ocaml
          | :sql
          | :css
          | :html
          | :dockerfile
          | :toml
          | :yaml
          | :hcl
          | :json
          | :markdown
          | :text
          | :unknown
  @type token :: {atom(), String.t()}
  @type theme :: %{atom() => {:color, String.t()}}

  @doc """
  Aplica syntax highlighting a una línea de código.

  ## Parámetros

  - `line` - Línea de texto
  - `file_type` - Tipo de archivo
  - `theme` - Mapa de colores por token

  ## Retornos

  Lista de células con colores aplicados
  """
  @spec highlight_line(String.t(), file_type(), map()) :: [Cell.t()]
  def highlight_line(line, file_type, theme \\ default_theme()) do
    # Obtener reglas para el tipo de archivo
    rules = Rules.rules_for(file_type)

    # Usar reglas dinámicas
    Rules.highlight_line(line, rules, theme)
  end

  @doc """
  Tokeniza una línea según el tipo de archivo.
  """
  @spec tokenize(String.t(), file_type()) :: [token()]
  def tokenize(line, :elixir), do: tokenize_elixir(line)
  def tokenize(line, :json), do: tokenize_json(line)
  def tokenize(line, :markdown), do: tokenize_markdown(line)

  def tokenize(line, type) when is_atom(type) do
    # Use declarative rules for all other languages
    Rules.tokenize(line, Rules.rules_for(type))
  end

  @doc """
  Colores por defecto para syntax highlighting.
  """
  @spec default_theme() :: map()
  def default_theme do
    %{
      keyword: {:color, "#569CD6"},
      string: {:color, "#CE9178"},
      comment: {:color, "#6A9955"},
      function: {:color, "#DCDCAA"},
      type: {:color, "#4EC9B0"},
      number: {:color, "#B5CEA8"},
      operator: {:color, "#D4D4D4"},
      atom: {:color, "#569CD6"},
      variable: {:color, "#9CDCFE"},
      text: {:color, "#D4D4D4"}
    }
  end

  @doc """
  Detecta el tipo de archivo por su extensión.

  ## Parámetros

  - `path` - Ruta del archivo o nombre del archivo

  ## Ejemplos

      iex> Syntax.detect_file_type("lib/my_module.ex")
      :elixir

      iex> Syntax.detect_file_type("config.json")
      :json

      iex> Syntax.detect_file_type("README.md")
      :markdown

      iex> Syntax.detect_file_type("archivo.txt")
      :text

  """
  @spec detect_file_type(Path.t()) :: file_type()
  def detect_file_type(path) when is_binary(path) do
    ext = Path.extname(path) |> String.downcase()
    base = Path.basename(path) |> String.downcase()

    # Special filenames (no extension or ambiguous)
    cond do
      base == "dockerfile" -> :dockerfile
      base in ["makefile", "gnumakefile"] -> :bash
      String.ends_with?(base, "rc") and not String.contains?(base, ".") -> :bash
      true -> detect_by_ext(ext)
    end
  end

  @ext_to_lang %{
    # Elixir / Erlang
    ".ex" => :elixir,
    ".exs" => :elixir,
    ".erl" => :erlang,
    ".hrl" => :erlang,
    # Python
    ".py" => :python,
    ".pyw" => :python,
    # TypeScript / JavaScript
    ".ts" => :typescript,
    ".tsx" => :tsx,
    ".js" => :javascript,
    ".jsx" => :javascript,
    ".mjs" => :javascript,
    ".cjs" => :javascript,
    # Rust
    ".rs" => :rust,
    # Go
    ".go" => :go,
    # Java / Kotlin
    ".java" => :java,
    ".kt" => :kotlin,
    ".kts" => :kotlin,
    # C# / C / C++
    ".cs" => :csharp,
    ".c" => :c,
    ".h" => :c,
    ".cpp" => :cpp,
    ".cc" => :cpp,
    ".cxx" => :cpp,
    ".hpp" => :cpp,
    ".hxx" => :cpp,
    # PHP
    ".php" => :php,
    # Ruby
    ".rb" => :ruby,
    # Swift
    ".swift" => :swift,
    # Dart
    ".dart" => :dart,
    # Scala
    ".scala" => :scala,
    ".sc" => :scala,
    # Lua
    ".lua" => :lua,
    # Bash / Shell
    ".sh" => :bash,
    ".bash" => :bash,
    ".zsh" => :bash,
    # R
    ".r" => :r,
    ".R" => :r,
    # Haskell
    ".hs" => :haskell,
    ".lhs" => :haskell,
    # Clojure
    ".clj" => :clojure,
    ".cljs" => :clojure,
    ".cljc" => :clojure,
    ".edn" => :clojure,
    # Zig
    ".zig" => :zig,
    # Nim
    ".nim" => :nim,
    # OCaml
    ".ml" => :ocaml,
    ".mli" => :ocaml,
    # SQL
    ".sql" => :sql,
    # CSS
    ".css" => :css,
    ".scss" => :css,
    ".less" => :css,
    # HTML
    ".html" => :html,
    ".htm" => :html,
    ".xml" => :html,
    # Config formats
    ".json" => :json,
    ".toml" => :toml,
    ".yaml" => :yaml,
    ".yml" => :yaml,
    ".tf" => :hcl,
    ".hcl" => :hcl,
    # Markdown
    ".md" => :markdown,
    ".markdown" => :markdown
  }

  defp detect_by_ext(ext) do
    Map.get(@ext_to_lang, ext, :text)
  end

  @doc """
  Aplica syntax highlighting a un archivo completo.

  Detecta automáticamente el tipo de archivo por la extensión.

  ## Parámetros

  - `path` - Ruta del archivo a highlightear
  - `theme` - Tema de colores (opcional, usa default_theme/0)

  ## Retornos

  Lista de líneas, donde cada línea es una lista de células coloreadas

  ## Ejemplos

      iex> Syntax.highlight_file("lib/my_module.ex")
      [[%Cell{...}], [%Cell{...}], ...]

  """
  @spec highlight_file(Path.t(), theme()) :: [[Cell.t()]]
  def highlight_file(path, theme \\ default_theme()) do
    file_type = detect_file_type(path)

    case File.read(path) do
      {:ok, content} ->
        highlight_content(content, file_type, theme)

      {:error, _} ->
        []
    end
  end

  @doc """
  Aplica syntax highlighting a contenido de texto.

  ## Parámetros

  - `content` - Contenido de texto a highlightear
  - `file_type` - Tipo de archivo (:elixir, :json, :markdown, :text)
  - `theme` - Tema de colores (opcional)

  ## Retornos

  Lista de líneas, donde cada línea es una lista de células coloreadas

  """
  @spec highlight_content(String.t(), file_type(), theme()) :: [[Cell.t()]]
  def highlight_content(content, file_type, theme \\ default_theme()) do
    content
    |> String.split("\n")
    |> Enum.map(&highlight_line(&1, file_type, theme))
  end

  # ───────────────────────────────────────────────────────────────────────
  # Elixir Tokenizer
  # ───────────────────────────────────────────────────────────────────────

  @elixir_keywords ~w[def defp defmodule defprotocol defimpl defrecord defstruct
                      defmacro defmacrop defdelegate defoverridable
                      if else case cond with for unless try rescue catch after
                      receive end do in and or not when fn ->
                      use import require alias]

  @elixir_operators ~w[=== !== == != <= >= && || ++ -- -> <- =>
                       &&& <<< >>> ^^~ |~> <~> ~>> <<~ ~>
                       + - * / = < > ! ^ & ~ :: |> <- --> => ~>]

  @spec tokenize_elixir(String.t()) :: [token()]
  defp tokenize_elixir(line) do
    line
    |> String.split(~r/(\s+|[(){}\[\],.]|["'#])/, include_captures: true)
    |> Enum.map(&classify_elixir_token/1)
  end

  @spec classify_elixir_token(String.t()) :: token()
  defp classify_elixir_token(token) do
    classify_atom_token(token) || classify_elixir_other(token)
  end

  defp classify_atom_token(token) do
    cond do
      # Atoms (quoted)
      token =~ ~r/^:".*"$/ or token =~ ~r/^'.*'$/ ->
        {:atom, token}

      # Atoms (unquoted)
      String.starts_with?(token, ":") and String.length(token) > 1 ->
        {:atom, token}

      true ->
        nil
    end
  end

  defp classify_elixir_other(token) do
    cond do
      # Numbers
      token =~ ~r/^\d+$/ ->
        {:number, token}

      # Strings
      token =~ ~r/^".*"$/ ->
        {:string, token}

      # Comments
      token =~ ~r/^#.*/ ->
        {:comment, token}

      # Keywords
      token in @elixir_keywords ->
        {:keyword, token}

      # Operators
      token in @elixir_operators ->
        {:operator, token}

      # Types (start with uppercase)
      String.match?(token, ~r/^[A-Z]/) ->
        {:type, token}

      # Functions and variables
      String.match?(token, ~r/^[a-z_][a-zA-Z0-9_]*[?!]?$/) ->
        classify_function_or_variable(token)

      # Default
      true ->
        {:text, token}
    end
  end

  defp classify_function_or_variable(token) do
    if String.ends_with?(token, "?") or String.ends_with?(token, "!") do
      {:function, token}
    else
      {:variable, token}
    end
  end

  # ───────────────────────────────────────────────────────────────────────
  # JSON Tokenizer
  # ───────────────────────────────────────────────────────────────────────

  @spec tokenize_json(String.t()) :: [token()]
  defp tokenize_json(line) do
    line
    |> String.split(~r/(\s+|[{}:\[\],])/, include_captures: true)
    |> Enum.map(&classify_json_token/1)
  end

  @spec classify_json_token(String.t()) :: token()
  defp classify_json_token(token) do
    cond do
      token =~ ~r/^".*"$/ ->
        {:string, token}

      token =~ ~r/^\d+\.?\d*$/ ->
        {:number, token}

      token in ["true", "false", "null"] ->
        {:keyword, token}

      token in ["{", "}", "[", "]", ":", ","] ->
        {:operator, token}

      true ->
        {:text, token}
    end
  end

  # ───────────────────────────────────────────────────────────────────────
  # Markdown Tokenizer
  # ───────────────────────────────────────────────────────────────────────

  @spec tokenize_markdown(String.t()) :: [token()]
  defp tokenize_markdown(line) do
    cond do
      String.starts_with?(line, "#") ->
        [{:keyword, line}]

      String.starts_with?(line, "- ") or String.starts_with?(line, "* ") ->
        [{:operator, String.slice(line, 0, 2)}, {:text, String.slice(line, 2..-1//-1)}]

      String.starts_with?(line, ">") ->
        [{:comment, line}]

      String.match?(line, ~r/\*\*.*\*\*/) ->
        tokenize_inline_formatting(line, :bold)

      String.match?(line, ~r/\*.*\*/) ->
        tokenize_inline_formatting(line, :italic)

      String.match?(line, ~r/`.*`/) ->
        tokenize_inline_formatting(line, :code)

      true ->
        [{:text, line}]
    end
  end

  @spec tokenize_inline_formatting(String.t(), atom()) :: [token()]
  defp tokenize_inline_formatting(line, :bold) do
    case Regex.run(~r/(.*)\*\*(.*)\*\*(.*)/, line, capture: :all_but_first) do
      [before, content, after_text] ->
        [{:text, before}, {:keyword, "**#{content}**"}, {:text, after_text}]

      nil ->
        [{:text, line}]
    end
  end

  defp tokenize_inline_formatting(line, :italic) do
    case Regex.run(~r/(.*)\*(.*)\*(.*)/, line, capture: :all_but_first) do
      [before, content, after_text] ->
        [{:text, before}, {:keyword, "*#{content}*"}, {:text, after_text}]

      nil ->
        [{:text, line}]
    end
  end

  defp tokenize_inline_formatting(line, :code) do
    case Regex.run(~r/(.*)`(.*)`(.*)/, line, capture: :all_but_first) do
      [before, content, after_text] ->
        [{:text, before}, {:string, "`#{content}`"}, {:text, after_text}]

      nil ->
        [{:text, line}]
    end
  end
end
