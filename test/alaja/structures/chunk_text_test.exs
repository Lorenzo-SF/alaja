defmodule Alaja.Structures.ChunkTextTest do
  use ExUnit.Case, async: true

  alias Alaja.Structures.{ChunkText, EffectInfo}
  alias Pote.ColorInfo

  describe "new/1" do
    test "creates ChunkText with empty text" do
      ct = ChunkText.new("")
      assert ct.text == ""
      assert ct.color == nil
      assert ct.bg_color == nil
      assert ct.effects == nil
    end

    test "creates ChunkText with text" do
      ct = ChunkText.new("Hello")
      assert ct.text == "Hello"
    end

    test "creates ChunkText with non-empty text" do
      ct = ChunkText.new("Hello world")
      assert ct.text == "Hello world"
    end

    test "creates ChunkText with unicode" do
      ct = ChunkText.new("Hello 世界")
      assert ct.text == "Hello 世界"
    end

    test "creates ChunkText with emojis" do
      ct = ChunkText.new("Hello 🌍")
      assert ct.text == "Hello 🌍"
    end
  end

  describe "new/2 with color option" do
    test "creates ChunkText with atom color" do
      ct = ChunkText.new("Hello", color: :red)
      assert ct.color.rgb == {255, 0, 0}
      assert ct.color.name == :red
    end

    test "creates ChunkText with hex color" do
      ct = ChunkText.new("Hello", color: "#FF0000")
      assert ct.color.rgb == {255, 0, 0}
    end

    test "creates ChunkText with RGB tuple" do
      ct = ChunkText.new("Hello", color: {255, 0, 0})
      assert ct.color.rgb == {255, 0, 0}
    end

    test "creates ChunkText with ColorInfo struct" do
      ci = ColorInfo.new(:blue)
      ct = ChunkText.new("Hello", color: ci)
      assert ct.color.rgb == {0, 0, 255}
    end

    test "creates ChunkText with bg_color option" do
      ct = ChunkText.new("Hello", bg_color: :blue)
      assert ct.bg_color.rgb == {0, 0, 255}
      assert ct.bg_color.name == :blue
    end

    test "creates ChunkText with both color and bg_color" do
      ct = ChunkText.new("Hello", color: :red, bg_color: :blue)
      assert ct.color.rgb == {255, 0, 0}
      assert ct.color.name == :red
      assert ct.bg_color.rgb == {0, 0, 255}
      assert ct.bg_color.name == :blue
    end
  end

  describe "new/2 with effects option" do
    test "creates ChunkText with single effect" do
      ct = ChunkText.new("Hello", effects: [:bold])
      assert ct.effects.bold == true
    end

    test "creates ChunkText with multiple effects" do
      ct = ChunkText.new("Hello", effects: [:bold, :underline])
      assert ct.effects.bold == true
      assert ct.effects.underline == true
    end

    test "creates ChunkText with EffectInfo struct" do
      ei = EffectInfo.new(:italic)
      ct = ChunkText.new("Hello", effects: ei)
      assert ct.effects == ei
    end

    test "creates ChunkText with empty effects list" do
      ct = ChunkText.new("Hello", effects: [])
      assert is_struct(ct.effects, EffectInfo)
    end
  end

  describe "new/2 with combined options" do
    test "creates ChunkText with color and effects" do
      ct = ChunkText.new("Hello", color: :red, effects: [:bold])
      assert ct.color.rgb == {255, 0, 0}
      assert ct.effects.bold == true
    end

    test "creates ChunkText with all options" do
      ct =
        ChunkText.new("Hello",
          color: :blue,
          bg_color: :white,
          effects: [:bold, :underline]
        )

      assert ct.color.rgb == {0, 0, 255}
      assert ct.bg_color.rgb == {255, 255, 255}
      assert ct.effects.bold == true
      assert ct.effects.underline == true
    end

    test "creates ChunkText with bright colors" do
      ct = ChunkText.new("Hello", color: :bright_green)
      assert ct.color.name == :bright_green
    end
  end

  describe "combine/2" do
    test "combines two ChunkTexts" do
      c1 = ChunkText.new("Hello")
      c2 = ChunkText.new(" World")
      combined = ChunkText.combine(c1, c2)
      assert combined.text == "Hello World"
    end

    test "second chunk color takes precedence" do
      c1 = ChunkText.new("Hello", color: :red)
      c2 = ChunkText.new(" World", color: :blue)
      combined = ChunkText.combine(c1, c2)
      assert combined.color.name == :blue
    end

    test "second chunk bg_color takes precedence" do
      c1 = ChunkText.new("Hello", bg_color: :red)
      c2 = ChunkText.new(" World", bg_color: :blue)
      combined = ChunkText.combine(c1, c2)
      assert combined.bg_color.name == :blue
    end

    test "combines effects" do
      c1 = ChunkText.new("Hello", effects: [:bold])
      c2 = ChunkText.new(" World", effects: [:italic])
      combined = ChunkText.combine(c1, c2)
      assert combined.effects.bold == true
      assert combined.effects.italic == true
    end

    test "handles nil color in first chunk" do
      c1 = ChunkText.new("Hello")
      c2 = ChunkText.new(" World", color: :red)
      combined = ChunkText.combine(c1, c2)
      assert combined.color.name == :red
    end

    test "handles nil color in second chunk" do
      c1 = ChunkText.new("Hello", color: :red)
      c2 = ChunkText.new(" World")
      combined = ChunkText.combine(c1, c2)
      assert combined.color.name == :red
    end

    test "combines empty strings" do
      c1 = ChunkText.new("")
      c2 = ChunkText.new("")
      combined = ChunkText.combine(c1, c2)
      assert combined.text == ""
    end

    test "combines empty with non-empty" do
      c1 = ChunkText.new("")
      c2 = ChunkText.new("World")
      combined = ChunkText.combine(c1, c2)
      assert combined.text == "World"
    end
  end

  describe "render/1" do
    test "renders plain text without ANSI codes" do
      ct = ChunkText.new("Hello")
      result = ChunkText.render(ct)
      assert result == "Hello"
    end

    test "renders text with color" do
      ct = ChunkText.new("Hello", color: :red)
      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "\e["
      assert result =~ "\e[0m"
    end

    test "renders text with background color" do
      ct = ChunkText.new("Hello", bg_color: :blue)
      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "\e["
    end

    test "renders text with effects" do
      ct = ChunkText.new("Hello", effects: [:bold])
      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "1"
    end

    test "renders text with color and effects" do
      ct = ChunkText.new("Hello", color: :red, effects: [:bold])
      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "31"
      assert result =~ "1"
    end

    test "renders text with bg_color and effects" do
      ct = ChunkText.new("Hello", bg_color: :blue, effects: [:underline])
      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "4"
    end

    test "renders with invert effect (triggers inverted mode)" do
      ct = ChunkText.new("Hello", effects: [:invert])
      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "\e[0m"
    end

    test "renders with reverse effect (triggers inverted mode)" do
      ct = ChunkText.new("Hello", effects: [:reverse])
      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "\e[0m"
    end

    test "renders with reverse effect and color (inverted mode)" do
      ct = ChunkText.new("Hello", color: :red, effects: [:reverse])
      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "\e[0m"
    end

    test "renders empty string" do
      ct = ChunkText.new("")
      result = ChunkText.render(ct)
      assert result == ""
    end

    test "renders unicode text" do
      ct = ChunkText.new("Hello 世界", color: :blue)
      result = ChunkText.render(ct)
      assert result =~ "Hello 世界"
    end

    test "ends with reset code" do
      ct = ChunkText.new("Hello", color: :red)
      result = ChunkText.render(ct)
      assert String.ends_with?(result, "\e[0m")
    end

    test "plain text does not have reset" do
      ct = ChunkText.new("Hello")
      result = ChunkText.render(ct)
      refute result =~ "\e[0m"
    end

    test "renders with all effects combined" do
      ct =
        ChunkText.new("Hello",
          color: :red,
          bg_color: :blue,
          effects: [:bold, :underline, :italic]
        )

      result = ChunkText.render(ct)
      assert result =~ "Hello"
      assert result =~ "31"
      assert result =~ "1"
      assert result =~ "4"
      assert result =~ "3"
    end
  end

  describe "struct fields" do
    test "has all expected fields" do
      ct = ChunkText.new("Hello")
      assert Map.has_key?(ct, :text)
      assert Map.has_key?(ct, :color)
      assert Map.has_key?(ct, :bg_color)
      assert Map.has_key?(ct, :effects)
    end
  end
end
