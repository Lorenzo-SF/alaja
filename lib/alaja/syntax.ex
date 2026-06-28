defmodule Alaja.Syntax do
  @moduledoc """
  Syntax highlighting for terminal output.

  Two-tier system:
  - **Built-in languages** (`:elixir`, `:json`, `:markdown`, `:text`)
    use inline tokenizers for Alaja's own CLI.
  - **Registered languages** (Python, TypeScript, Rust, etc.) use
    `Alaja.Syntax.Engine` driven by `Alaja.Syntax.Language` definitions,
    typically registered by host applications (e.g. Delfos).

  ## Usage

      # Built-in
      Alaja.Syntax.highlight_content(code, :elixir)

      # Registered by host app
      Alaja.Syntax.highlight_content(code, :python)

  ## Registering a language

      alias Alaja.Syntax.Language

      Alaja.Syntax.register_language(:python, %Language{
        name: "Python",
        line_comment: "#",
        keywords: MapSet.new(~w(def class if elif else for while return)),
        colors: %{keyword: {:blue, [:bold]}}
      })
  """

  alias Alaja.Syntax.{Engine, Language, Renderer}

  @type language ::
          :elixir
          | :json
          | :markdown
          | :text
          | :python
          | :typescript
          | :rust
          | :go
          | :java
          | :ruby

  @type token :: {atom(), String.t()}

  # ── Built-in inline tokenizers (kept for backward compat) ──────────────

  @elixir_keywords ~w(def defmodule defp do end case cond if else when with fn
                       use import alias require receive send raise try catch
                       after rescue throw for while return)

  @doc """
  Highlights a file by detecting language from extension.
  """
  @spec highlight_file(String.t()) :: {:ok, list()} | {:error, String.t()}
  def highlight_file(path) do
    case File.read(path) do
      {:ok, content} ->
        lang = detect_language(path)
        {:ok, highlight_content(content, lang)}

      {:error, reason} ->
        {:error, "cannot read file: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Highlights source code for a given language.

  Returns `[{color_string, text}]` tuples. For ANSI-rendered output
  use `highlight_ansi/2`.
  """
  @spec highlight_content(String.t(), language()) :: [{String.t(), String.t()}]
  def highlight_content(content, language) do
    tokens = tokenize(content, language)

    case language do
      :elixir ->
        Enum.map(tokens, fn {type, text} -> {color_for(type), text} end)

      :json ->
        Enum.map(tokens, fn {type, text} -> {color_for(type), text} end)

      :markdown ->
        Enum.map(tokens, fn {type, text} -> {color_for(type), text} end)

      :text ->
        [{"white", content}]

      _ ->
        case get_language(language) do
          {:ok, lang} -> Renderer.render(tokens, lang)
          :error -> [{"white", content}]
        end
    end
  end

  @doc """
  Highlights source code and returns ANSI escape sequences.

  Same API as `highlight_content/2` but produces terminal-ready output.
  """
  @spec highlight_ansi(String.t(), language()) :: IO.iodata()
  def highlight_ansi(content, language) do
    tokens = tokenize(content, language)

    case get_language(language) do
      {:ok, lang} -> Renderer.render_ansi(tokens, lang)
      :error -> highlight_content(content, language) |> Enum.map_join(fn {_, t} -> t end)
    end
  end

  @doc """
  Tokenizes source code into `{type, text}` tuples.
  """
  @spec tokenize(String.t(), language()) :: [token()]
  def tokenize(content, language) do
    case language do
      :elixir ->
        tokenize_elixir(content)

      :json ->
        tokenize_json(content)

      :markdown ->
        tokenize_markdown(content)

      :text ->
        [{:plain, content}]

      _ ->
        case get_language(language) do
          {:ok, lang} -> Engine.tokenize(content, lang)
          :error -> [{:plain, content}]
        end
    end
  end

  # ── Language registry ─────────────────────────────────────────────────

  @doc """
  Registers a language definition under an atom key.
  """
  @spec register_language(atom(), Language.t()) :: :ok
  def register_language(name, %Language{} = lang) do
    :persistent_term.put({:alaja_syntax, name}, lang)
    __register_key__(name)
  end

  @doc """
  Retrieves a registered language definition.
  """
  @spec get_language(atom()) :: {:ok, Language.t()} | :error
  def get_language(name) when is_atom(name) do
    case :persistent_term.get({:alaja_syntax, name}, :not_found) do
      :not_found -> :error
      lang -> {:ok, lang}
    end
  end

  @doc "Lists all registered language names."
  @spec list_languages() :: [atom()]
  def list_languages do
    :persistent_term.get(:alaja_syntax_keys, [])
  end

  @doc false
  def __register_key__(name) do
    keys = :persistent_term.get(:alaja_syntax_keys, [])
    :persistent_term.put(:alaja_syntax_keys, [name | keys] |> Enum.uniq())
  end

  # ── Built-in tokenizers (unchanged) ───────────────────────────────────

  # Split content into lines for built-in tokenizers
  defp tokenize_elixir(content) do
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
        text -> classify_token(text)
      end

    if rest == "" or rest == line do
      Enum.reverse([{type, text} | acc])
    else
      tokenize_elixir_parts(rest, [{type, text} | acc])
    end
  end

  defp classify_token(text) do
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

  defp tokenize_json(content) do
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

  defp tokenize_markdown(content) do
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

  defp color_for(:keyword), do: "blue"
  defp color_for(:string), do: "green"
  defp color_for(:comment), do: "gray"
  defp color_for(:number), do: "cyan"
  defp color_for(:operator), do: "white"
  defp color_for(:atom), do: "yellow"
  defp color_for(:module), do: "magenta"
  defp color_for(:plain), do: "white"
  defp color_for(_), do: "white"

  # ── Language detection (from file extension) ─────────────────────────

  @doc "Detects language atom from file path extension."
  @spec detect_language(String.t()) :: atom()
  def detect_language(path) do
    case Path.extname(path) do
      ".ex" ->
        :elixir

      ".exs" ->
        :elixir

      ".erl" ->
        :erlang

      ".hrl" ->
        :erlang

      ".json" ->
        :json

      ".md" ->
        :markdown

      ".py" ->
        :python

      ".ts" ->
        :typescript

      ".tsx" ->
        :typescript

      ".rs" ->
        :rust

      ".go" ->
        :go

      ".java" ->
        :java

      ".rb" ->
        :ruby

      ".js" ->
        :javascript

      ".jsx" ->
        :javascript

      ".mjs" ->
        :javascript

      ".cjs" ->
        :javascript

      ".c" ->
        :c

      ".h" ->
        :c

      ".cpp" ->
        :cpp

      ".cxx" ->
        :cpp

      ".cc" ->
        :cpp

      ".hpp" ->
        :cpp

      ".cs" ->
        :csharp

      ".kt" ->
        :kotlin

      ".kts" ->
        :kotlin

      ".swift" ->
        :swift

      ".scala" ->
        :scala

      ".dart" ->
        :dart

      ".php" ->
        :php

      ".phtml" ->
        :php

      ".pl" ->
        :perl

      ".pm" ->
        :perl

      ".r" ->
        :r

      ".jl" ->
        :julia

      ".lua" ->
        :lua

      ".hs" ->
        :haskell

      ".lhs" ->
        :haskell

      ".clj" ->
        :clojure

      ".cljs" ->
        :clojure

      ".cljc" ->
        :clojure

      ".ml" ->
        :ocaml

      ".mli" ->
        :ocaml

      ".sh" ->
        :bash

      ".bash" ->
        :bash

      ".zsh" ->
        :bash

      ".ps1" ->
        :powershell

      ".psm1" ->
        :powershell

      ".sql" ->
        :sql

      ".graphql" ->
        :graphql

      ".gql" ->
        :graphql

      ".html" ->
        :html

      ".htm" ->
        :html

      ".css" ->
        :css

      ".yaml" ->
        :yaml

      ".yml" ->
        :yaml

      ".toml" ->
        :toml

      ".zig" ->
        :zig

      ".nim" ->
        :nim

      ".cr" ->
        :crystal

      ".d" ->
        :dlang

      ".f" ->
        :fortran

      ".f90" ->
        :fortran

      ".f95" ->
        :fortran

      ".ada" ->
        :ada

      ".adb" ->
        :ada

      ".ads" ->
        :ada

      ".pas" ->
        :pascal

      ".pp" ->
        :pascal

      ".pro" ->
        :prolog

      ".rkt" ->
        :racket

      ".lisp" ->
        :lisp

      ".cl" ->
        :lisp

      ".el" ->
        :lisp

      ".sol" ->
        :solidity

      ".tf" ->
        :terraform

      ".hcl" ->
        :terraform

      ".gleam" ->
        :gleam

      ".purs" ->
        :purescript

      ".ha" ->
        :hare

      ".odin" ->
        :odin

      ".v" ->
        :vlang

      ".wat" ->
        :wat

      ".wast" ->
        :wat

      ".bf" ->
        :brainfuck

      ".coffee" ->
        :coffeescript

      ".xml" ->
        :xml

      ".svg" ->
        :xml

      ".xsd" ->
        :xml

      ".xsl" ->
        :xml

      ".tex" ->
        :tex

      ".sty" ->
        :tex

      ".cls" ->
        :tex

      ".ltx" ->
        :tex

      ".m" ->
        :matlab

      ".groovy" ->
        :groovy

      ".gvy" ->
        :groovy

      ".gradle" ->
        :gradle

      ".gradle.kts" ->
        :gradle

      ".hx" ->
        :haxe

      ".hxs" ->
        :haxe

      ".hxp" ->
        :haxe

      ".st" ->
        :smalltalk

      ".tcl" ->
        :tcl

      ".mm" ->
        :objc

      ".vue" ->
        :vue

      ".svelte" ->
        :svelte

      ".applescript" ->
        :applescript

      ".scpt" ->
        :applescript

      "" ->
        case Path.basename(path) do
          "Dockerfile" -> :dockerfile
          "Makefile" -> :makefile
          "makefile" -> :makefile
          "GNUmakefile" -> :makefile
          _ -> :text
        end

      _ ->
        :text
    end
  end
end
