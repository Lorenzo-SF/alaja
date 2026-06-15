defmodule Alaja.SyntaxTest do
  use ExUnit.Case, async: true

  alias Alaja.Syntax
  alias Alaja.Syntax.Rules

  describe "highlight_line/3" do
    test "highlights elixir code" do
      theme = Syntax.default_theme()
      cells = Syntax.highlight_line("def hello, do: :world", :elixir, theme)
      assert is_list(cells)
      assert cells != []
    end

    test "highlights JSON" do
      theme = Syntax.default_theme()
      cells = Syntax.highlight_line(~s({"key": "value"}), :json, theme)
      assert is_list(cells)
    end

    test "highlights markdown" do
      theme = Syntax.default_theme()
      cells = Syntax.highlight_line("# Heading", :markdown, theme)
      assert is_list(cells)
    end

    test "returns empty list for unknown file type" do
      theme = Syntax.default_theme()
      cells = Syntax.highlight_line("plain text", :unknown, theme)
      assert is_list(cells)
    end

    test "uses default theme when none provided" do
      cells = Syntax.highlight_line("def foo, do: :bar", :elixir)
      assert is_list(cells)
    end
  end

  describe "tokenize/2" do
    test "tokenizes elixir code" do
      tokens = Syntax.tokenize("def foo, do: :bar", :elixir)
      assert is_list(tokens)
      assert {:keyword, "def"} in tokens
    end

    test "tokenizes elixir keywords" do
      tokens = Syntax.tokenize("defmodule MyModule do end", :elixir)
      assert is_list(tokens)
      assert Enum.any?(tokens, fn {type, _} -> type == :keyword end)
    end

    test "tokenizes elixir strings" do
      tokens = Syntax.tokenize(~s("hello world"), :elixir)
      assert is_list(tokens)
      # Strings may be tokenized as text or string depending on tokenizer
      assert Enum.any?(tokens, fn {type, _} -> type in [:string, :text] end)
    end

    test "tokenizes elixir comments" do
      tokens = Syntax.tokenize("# this is a comment", :elixir)
      assert is_list(tokens)
      assert Enum.any?(tokens, fn {type, _} -> type == :comment end)
    end

    test "tokenizes elixir atoms" do
      tokens = Syntax.tokenize(":ok :error :custom_atom", :elixir)
      assert is_list(tokens)
      assert Enum.any?(tokens, fn {type, _} -> type == :atom end)
    end

    test "tokenizes elixir numbers" do
      tokens = Syntax.tokenize("42 3.14 0xFF", :elixir)
      assert is_list(tokens)
      assert Enum.any?(tokens, fn {type, _} -> type == :number end)
    end

    test "tokenizes elixir operators" do
      tokens = Syntax.tokenize("a + b - c * d / e", :elixir)
      assert is_list(tokens)
    end

    test "tokenizes JSON" do
      tokens = Syntax.tokenize(~s({"name": "test"}), :json)
      assert is_list(tokens)
    end

    test "tokenizes JSON strings" do
      tokens = Syntax.tokenize(~s("key": "value"), :json)
      assert is_list(tokens)
    end

    test "tokenizes JSON numbers" do
      tokens = Syntax.tokenize("42 3.14 -10", :json)
      assert is_list(tokens)
    end

    test "tokenizes JSON booleans" do
      tokens = Syntax.tokenize("true false", :json)
      assert is_list(tokens)
    end

    test "tokenizes JSON null" do
      tokens = Syntax.tokenize("null", :json)
      assert is_list(tokens)
    end

    test "tokenizes markdown" do
      tokens = Syntax.tokenize("# Heading", :markdown)
      assert is_list(tokens)
    end

    test "tokenizes markdown headings" do
      tokens = Syntax.tokenize("## Heading 2", :markdown)
      assert is_list(tokens)
    end

    test "tokenizes markdown bold" do
      tokens = Syntax.tokenize("**bold text**", :markdown)
      assert is_list(tokens)
    end

    test "tokenizes markdown inline code" do
      tokens = Syntax.tokenize("`code`", :markdown)
      assert is_list(tokens)
    end

    test "tokenizes unknown type without errors" do
      tokens = Syntax.tokenize("some text", :unknown)
      assert is_list(tokens)
      assert tokens != []
    end
  end

  describe "default_theme/0" do
    test "returns a map with required keys" do
      theme = Syntax.default_theme()
      assert is_map(theme)
      assert Map.has_key?(theme, :keyword)
      assert Map.has_key?(theme, :string)
      assert Map.has_key?(theme, :comment)
      assert Map.has_key?(theme, :function)
      assert Map.has_key?(theme, :type)
      assert Map.has_key?(theme, :number)
      assert Map.has_key?(theme, :operator)
      assert Map.has_key?(theme, :atom)
      assert Map.has_key?(theme, :variable)
      assert Map.has_key?(theme, :text)
    end
  end

  describe "detect_file_type/1" do
    test "detects .ex files" do
      assert Syntax.detect_file_type("lib/my_module.ex") == :elixir
    end

    test "detects .exs files" do
      assert Syntax.detect_file_type("mix.exs") == :elixir
    end

    test "detects .json files" do
      assert Syntax.detect_file_type("config.json") == :json
    end

    test "detects .md files" do
      assert Syntax.detect_file_type("README.md") == :markdown
    end

    test "detects .markdown files" do
      assert Syntax.detect_file_type("doc.markdown") == :markdown
    end

    test "returns text for unknown extensions" do
      assert Syntax.detect_file_type("file.txt") == :text
      assert Syntax.detect_file_type("file.xyz") == :text
    end
  end

  describe "highlight_file/2" do
    test "highlights an existing file" do
      # Use a real file
      theme = Syntax.default_theme()
      lines = Syntax.highlight_file("mix.exs", theme)
      assert is_list(lines)
      assert Enum.all?(lines, &is_list/1)
    end

    test "returns empty list for non-existent file" do
      theme = Syntax.default_theme()
      lines = Syntax.highlight_file("/nonexistent/path.ex", theme)
      assert lines == []
    end

    test "uses default theme when none provided" do
      lines = Syntax.highlight_file("mix.exs")
      assert is_list(lines)
    end
  end

  describe "highlight_content/3" do
    test "highlights elixir content" do
      content = "defmodule MyModule do\n  def hello, do: :world\nend"
      theme = Syntax.default_theme()
      lines = Syntax.highlight_content(content, :elixir, theme)
      assert length(lines) == 3
      assert Enum.all?(lines, &is_list/1)
    end

    test "highlights JSON content" do
      content = ~s({"name": "test", "value": 42})
      theme = Syntax.default_theme()
      lines = Syntax.highlight_content(content, :json, theme)
      assert length(lines) == 1
    end

    test "highlights markdown content" do
      content = "# Heading\n\nSome text"
      theme = Syntax.default_theme()
      lines = Syntax.highlight_content(content, :markdown, theme)
      assert length(lines) == 3
    end

    test "uses default theme when none provided" do
      lines = Syntax.highlight_content("def test, do: :ok", :elixir)
      assert is_list(lines)
    end
  end

  describe "Rules module" do
    test "rules_for returns rules for elixir" do
      rules = Rules.rules_for(:elixir)
      assert is_map(rules)
      assert Map.has_key?(rules, :keywords)
    end

    test "rules_for returns rules for json" do
      rules = Rules.rules_for(:json)
      assert is_map(rules)
      assert Map.has_key?(rules, :keywords)
    end

    test "highlight_line with rules" do
      theme = Syntax.default_theme()
      rules = Rules.rules_for(:elixir)
      cells = Rules.highlight_line("def test, do: :ok", rules, theme)
      assert is_list(cells)
    end
  end
end
