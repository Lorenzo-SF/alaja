defmodule Alaja.Syntax.RendererTest do
  use ExUnit.Case, async: true

  alias Alaja.Syntax.Language
  alias Alaja.Syntax.Renderer

  describe "render/3" do
    test "returns empty list for empty tokens" do
      lang = %Language{name: "x", colors: %{}}
      assert Renderer.render([], lang) == []
    end

    test "maps tokens to {color_name, text} pairs" do
      lang = %Language{
        name: "test",
        colors: %{keyword: {:blue, [:bold]}}
      }

      result = Renderer.render([{:keyword, "def"}], lang)
      assert [{"blue", "def"}] = result
    end

    test "returns a binary color for unknown types" do
      lang = %Language{name: "test", colors: %{}}
      [{color, "x"}] = Renderer.render([{:unknown_type, "x"}], lang)
      assert is_binary(color)
    end
  end

  describe "render_ansi/3" do
    test "empty tokens returns empty binary" do
      lang = %Language{name: "test", colors: %{}}
      assert IO.iodata_to_binary(Renderer.render_ansi([], lang)) == ""
    end
  end

  describe "render_plain/1" do
    test "joins text without colors" do
      tokens = [{:keyword, "def "}, {:plain, "x"}]
      assert Renderer.render_plain(tokens) == "def x"
    end

    test "empty tokens returns empty string" do
      assert Renderer.render_plain([]) == ""
    end
  end
end
