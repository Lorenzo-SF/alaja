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

  alias Alaja.{Buffer, Cell}
  alias Alaja.Syntax.{Builtin, Engine, Language, Renderer, Theme}

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
        Enum.map(tokens, fn {type, text} -> {Builtin.color_for(type), text} end)

      :json ->
        Enum.map(tokens, fn {type, text} -> {Builtin.color_for(type), text} end)

      :markdown ->
        Enum.map(tokens, fn {type, text} -> {Builtin.color_for(type), text} end)

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
  @spec highlight_ansi(String.t(), language()) :: iodata()
  def highlight_ansi(content, language) do
    tokens = tokenize(content, language)

    case get_language(language) do
      {:ok, lang} -> Renderer.render_ansi(tokens, lang)
      :error -> highlight_content(content, language) |> Enum.map_join(fn {_, t} -> t end)
    end
  end

  @doc """
  Highlights source code and returns an `Alaja.Buffer.t/0`.

  This is the Buffer-first canonical render. Each token becomes one
  cell per visible character with the resolved fg colour from the
  language/theme chain. Effects (`:bold`, `:italic`, ...) are stored
  on the cell but currently not visually distinct in the buffer — use
  `highlight_ansi/2` for full effect rendering.

  ## Options

    - `:theme` — overrides the global syntax theme (default: `Theme.default()`)
    - `:max_width` — wraps long lines; pass `false` to disable wrapping

  ## Examples

      buf = Alaja.Syntax.highlight_buffer("defmodule Foo do end", :elixir)
      Alaja.Printer.print_raw(buf)
  """
  @spec highlight_buffer(String.t(), language(), keyword()) :: Buffer.t()
  def highlight_buffer(content, language, opts \\ []) do
    theme = Keyword.get(opts, :theme) || Theme.default()

    # Built-in tokenizers (`:elixir`, `:json`, `:markdown`) split on '\n'
    # internally and never emit it as a token. We must split the content
    # into lines ourselves to preserve the visual layout.
    content_lines = String.split(content, "\n")
    tokens_by_line = Enum.map(content_lines, &tokenize(&1, language))

    resolved_lines =
      Enum.map(tokens_by_line, fn line_tokens ->
        Enum.map(line_tokens, &resolve_token(&1, language, theme))
      end)

    height = max(length(resolved_lines), 1)
    width = resolved_lines |> Enum.map(&line_visible_width/1) |> Enum.max(fn -> 0 end)

    buffer = Buffer.new(width, height)

    resolved_lines
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, y}, buf -> write_line(buf, y, line) end)
  end

  defp resolve_token({type, text}, language, theme) do
    color =
      case get_language(language) do
        {:ok, lang} ->
          {color_atom, _effects} = Theme.resolve(type, lang.colors, theme)
          color_to_rgb(color_atom)

        :error ->
          color_to_rgb(Builtin.color_for_atom(type))
      end

    {color, text}
  end

  defp write_fragment(buf, text, col, y, color) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buf, fn {char, idx}, b ->
      target_x = col + idx

      if target_x < b.width do
        Buffer.update_cell(b, target_x, y, Cell.new(char, color))
      else
        b
      end
    end)
  end

  defp line_visible_width(line) do
    Enum.reduce(line, 0, fn {_color, text}, acc -> acc + String.length(text) end)
  end

  defp write_line(buffer, y, line) do
    # Each fragment `{color, text}` occupies consecutive cells starting
    # at the running column. We track the column across fragments so
    # successive fragments don't overwrite each other.
    {final, _} =
      Enum.reduce(line, {buffer, 0}, fn {color, text}, {buf, col} ->
        new_buf = write_fragment(buf, text, col, y, color)
        {new_buf, col + String.length(text)}
      end)

    final
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
  defp tokenize_elixir(content), do: Builtin.tokenize_elixir(content)
  defp tokenize_json(content), do: Builtin.tokenize_json(content)
  defp tokenize_markdown(content), do: Builtin.tokenize_markdown(content)

  # ── Language detection (from file extension) ─────────────────────────

  @language_map %{
    ".ex" => :elixir,
    ".exs" => :elixir,
    ".erl" => :erlang,
    ".hrl" => :erlang,
    ".json" => :json,
    ".md" => :markdown,
    ".py" => :python,
    ".ts" => :typescript,
    ".tsx" => :typescript,
    ".rs" => :rust,
    ".go" => :go,
    ".java" => :java,
    ".rb" => :ruby,
    ".js" => :javascript,
    ".jsx" => :javascript,
    ".mjs" => :javascript,
    ".cjs" => :javascript,
    ".c" => :c,
    ".h" => :c,
    ".cpp" => :cpp,
    ".cxx" => :cpp,
    ".cc" => :cpp,
    ".hpp" => :cpp,
    ".cs" => :csharp,
    ".kt" => :kotlin,
    ".kts" => :kotlin,
    ".swift" => :swift,
    ".scala" => :scala,
    ".dart" => :dart,
    ".php" => :php,
    ".phtml" => :php,
    ".pl" => :perl,
    ".pm" => :perl,
    ".r" => :r,
    ".jl" => :julia,
    ".lua" => :lua,
    ".hs" => :haskell,
    ".lhs" => :haskell,
    ".clj" => :clojure,
    ".cljs" => :clojure,
    ".cljc" => :clojure,
    ".ml" => :ocaml,
    ".mli" => :ocaml,
    ".sh" => :bash,
    ".bash" => :bash,
    ".zsh" => :bash,
    ".ps1" => :powershell,
    ".psm1" => :powershell,
    ".sql" => :sql,
    ".graphql" => :graphql,
    ".gql" => :graphql,
    ".html" => :html,
    ".htm" => :html,
    ".css" => :css,
    ".yaml" => :yaml,
    ".yml" => :yaml,
    ".toml" => :toml,
    ".zig" => :zig,
    ".nim" => :nim,
    ".cr" => :crystal,
    ".d" => :dlang,
    ".f" => :fortran,
    ".f90" => :fortran,
    ".f95" => :fortran,
    ".ada" => :ada,
    ".adb" => :ada,
    ".ads" => :ada,
    ".pas" => :pascal,
    ".pp" => :pascal,
    ".pro" => :prolog,
    ".rkt" => :racket,
    ".lisp" => :lisp,
    ".cl" => :lisp,
    ".el" => :lisp,
    ".sol" => :solidity,
    ".tf" => :terraform,
    ".hcl" => :terraform,
    ".gleam" => :gleam,
    ".purs" => :purescript,
    ".ha" => :hare,
    ".odin" => :odin,
    ".v" => :vlang,
    ".wat" => :wat,
    ".wast" => :wat,
    ".bf" => :brainfuck,
    ".coffee" => :coffeescript,
    ".xml" => :xml,
    ".svg" => :xml,
    ".xsd" => :xml,
    ".xsl" => :xml,
    ".tex" => :tex,
    ".sty" => :tex,
    ".cls" => :tex,
    ".ltx" => :tex,
    ".m" => :matlab,
    ".groovy" => :groovy,
    ".gvy" => :groovy,
    ".gradle" => :gradle,
    ".gradle.kts" => :gradle,
    ".hx" => :haxe,
    ".hxs" => :haxe,
    ".hxp" => :haxe,
    ".st" => :smalltalk,
    ".tcl" => :tcl,
    ".mm" => :objc,
    ".vue" => :vue,
    ".svelte" => :svelte,
    ".applescript" => :applescript,
    ".scpt" => :applescript
  }

  @doc "Detects language atom from file path extension."
  @spec detect_language(String.t()) :: atom()
  def detect_language(path) do
    ext = Path.extname(path)

    if ext == "" do
      detect_basename_language(path)
    else
      Map.get(@language_map, ext, :text)
    end
  end

  defp detect_basename_language(path) do
    case Path.basename(path) do
      "Dockerfile" -> :dockerfile
      "Makefile" -> :makefile
      "makefile" -> :makefile
      "GNUmakefile" -> :makefile
      _ -> :text
    end
  end

  # ── Color resolution helpers ──────────────────────────────────────────

  defp color_to_rgb(atom) when is_atom(atom) do
    Map.get(Builtin.ansi_16_colors(), atom, {255, 255, 255})
  end

  defp color_to_rgb(string) when is_binary(string) do
    atom =
      try do
        String.to_existing_atom(string)
      rescue
        ArgumentError -> :white
      end

    color_to_rgb(atom)
  end

  defp color_to_rgb({r, g, b}) when is_integer(r) and is_integer(g) and is_integer(b) do
    {r, g, b}
  end
end
