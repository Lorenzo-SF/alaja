defmodule Alaja.SyntaxTest do
  use ExUnit.Case, async: true

  alias Alaja.Syntax

  describe "tokenize/2 — :elixir" do
    test "detects a keyword" do
      tokens = Syntax.tokenize("def hello do", :elixir)
      assert {:keyword, "def"} in tokens
    end

    test "marks a comment line as :comment" do
      tokens = Syntax.tokenize("# a comment line", :elixir)
      assert tokens == [{:comment, "# a comment line"}]
    end
  end

  describe "tokenize/2 — :json" do
    test "detects a number" do
      tokens = Syntax.tokenize("{\"key\": 42}", :json)
      assert {:number, "42"} in tokens
    end
  end

  describe "highlight_content/2" do
    test "returns a non-empty list for markdown" do
      assert [_ | _] = Syntax.highlight_content("# Title", :markdown)
    end

    test "returns the raw line for :text" do
      assert [{_, "hello"}] = Syntax.highlight_content("hello", :text)
    end
  end

  describe "highlight_file/1" do
    test "returns {:error, _} for a non-existent file" do
      assert {:error, _} = Syntax.highlight_file("noexiste.ex")
    end
  end
end
