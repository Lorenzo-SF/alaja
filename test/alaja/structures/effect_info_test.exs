defmodule Alaja.Structures.EffectInfoTest do
  use ExUnit.Case, async: true

  alias Alaja.Structures.EffectInfo

  describe "new/0" do
    test "creates empty EffectInfo" do
      ei = EffectInfo.new()
      assert ei.bold == false
      assert ei.dim == false
      assert ei.italic == false
      assert ei.underline == false
      assert ei.blink == false
      assert ei.reverse == false
      assert ei.invert == false
      assert ei.hidden == false
      assert ei.strikethrough == false
      assert ei.link == nil
    end
  end

  describe "new/1 with atom" do
    test "creates EffectInfo with :bold" do
      ei = EffectInfo.new(:bold)
      assert ei.bold == true
      assert ei.dim == false
      assert ei.italic == false
    end

    test "creates EffectInfo with :dim" do
      ei = EffectInfo.new(:dim)
      assert ei.dim == true
    end

    test "creates EffectInfo with :italic" do
      ei = EffectInfo.new(:italic)
      assert ei.italic == true
    end

    test "creates EffectInfo with :underline" do
      ei = EffectInfo.new(:underline)
      assert ei.underline == true
    end

    test "creates EffectInfo with :blink" do
      ei = EffectInfo.new(:blink)
      assert ei.blink == true
    end

    test "creates EffectInfo with :reverse" do
      ei = EffectInfo.new(:reverse)
      assert ei.reverse == true
    end

    test "creates EffectInfo with :invert" do
      ei = EffectInfo.new(:invert)
      assert ei.invert == true
    end

    test "creates EffectInfo with :hidden" do
      ei = EffectInfo.new(:hidden)
      assert ei.hidden == true
    end

    test "creates EffectInfo with :strikethrough" do
      ei = EffectInfo.new(:strikethrough)
      assert ei.strikethrough == true
    end

    test "ignores unknown atom" do
      ei = EffectInfo.new(:unknown_effect)
      assert ei.bold == false
      assert ei.dim == false
    end
  end

  describe "new/1 with list of atoms" do
    test "creates EffectInfo with multiple effects" do
      ei = EffectInfo.new([:bold, :underline])
      assert ei.bold == true
      assert ei.underline == true
      assert ei.italic == false
    end

    test "creates EffectInfo with single item list" do
      ei = EffectInfo.new([:bold])
      assert ei.bold == true
    end

    test "creates EffectInfo with empty list" do
      ei = EffectInfo.new([])
      assert ei.bold == false
    end

    test "creates EffectInfo with all effects" do
      ei =
        EffectInfo.new([
          :bold,
          :dim,
          :italic,
          :underline,
          :blink,
          :reverse,
          :invert,
          :hidden,
          :strikethrough
        ])

      assert ei.bold == true
      assert ei.dim == true
      assert ei.italic == true
      assert ei.underline == true
      assert ei.blink == true
      assert ei.reverse == true
      assert ei.invert == true
      assert ei.hidden == true
      assert ei.strikethrough == true
    end

    test "ignores unknown effects in list" do
      ei = EffectInfo.new([:bold, :unknown, :italic])
      assert ei.bold == true
      assert ei.italic == true
    end
  end

  describe "new/1 with string (URL)" do
    test "creates EffectInfo with link from URL string" do
      ei = EffectInfo.new("https://example.com")
      assert ei.link == "https://example.com"
      assert ei.bold == false
    end

    test "creates EffectInfo with link from map" do
      ei = EffectInfo.new(%{link: "https://test.com"})
      assert ei.link == "https://test.com"
    end

    test "empty string creates link" do
      ei = EffectInfo.new("")
      assert ei.link == ""
    end
  end

  describe "new/1 with EffectInfo struct" do
    test "returns the same struct" do
      original = EffectInfo.new([:bold, :italic])
      ei = EffectInfo.new(original)
      assert ei == original
    end
  end

  describe "new/1 with map" do
    test "creates EffectInfo from map" do
      ei = EffectInfo.new(%{bold: true, italic: true})
      assert ei.bold == true
      assert ei.italic == true
    end
  end

  describe "combine/2" do
    test "combines two EffectInfos with OR logic" do
      e1 = EffectInfo.new(:bold)
      e2 = EffectInfo.new(:italic)
      combined = EffectInfo.combine(e1, e2)
      assert combined.bold == true
      assert combined.italic == true
    end

    test "combine true with false returns true" do
      e1 = EffectInfo.new(:bold)
      e2 = EffectInfo.new()
      combined = EffectInfo.combine(e1, e2)
      assert combined.bold == true
    end

    test "combine false with true returns true" do
      e1 = EffectInfo.new()
      e2 = EffectInfo.new(:italic)
      combined = EffectInfo.combine(e1, e2)
      assert combined.italic == true
    end

    test "combine combines all boolean fields" do
      e1 = EffectInfo.new([:bold, :dim, :underline])
      e2 = EffectInfo.new([:italic, :blink, :strikethrough])
      combined = EffectInfo.combine(e1, e2)

      assert combined.bold == true
      assert combined.dim == true
      assert combined.underline == true
      assert combined.italic == true
      assert combined.blink == true
      assert combined.strikethrough == true
    end

    test "combine preserves link field" do
      e1 = EffectInfo.new(:bold)
      e2 = EffectInfo.new("https://example.com")
      combined = EffectInfo.combine(e1, e2)
      assert combined.link == "https://example.com"
      assert combined.bold == true
    end

    test "combine with nil link values" do
      e1 = EffectInfo.new(:bold)
      e2 = EffectInfo.new(:italic)
      combined = EffectInfo.combine(e1, e2)
      assert combined.link == nil
    end

    test "combine reverse and invert both result in true" do
      e1 = EffectInfo.new(:reverse)
      e2 = EffectInfo.new(:invert)
      combined = EffectInfo.combine(e1, e2)
      assert combined.reverse == true
      assert combined.invert == true
    end
  end

  describe "to_ansi/1" do
    test "returns empty string for EffectInfo with no effects" do
      ei = EffectInfo.new()
      assert EffectInfo.to_ansi(ei) == ""
    end

    test "returns ANSI code for :bold" do
      ei = EffectInfo.new(:bold)
      assert EffectInfo.to_ansi(ei) == "\e[1m"
    end

    test "returns ANSI code for :dim" do
      ei = EffectInfo.new(:dim)
      assert EffectInfo.to_ansi(ei) == "\e[2m"
    end

    test "returns ANSI code for :italic" do
      ei = EffectInfo.new(:italic)
      assert EffectInfo.to_ansi(ei) == "\e[3m"
    end

    test "returns ANSI code for :underline" do
      ei = EffectInfo.new(:underline)
      assert EffectInfo.to_ansi(ei) == "\e[4m"
    end

    test "returns ANSI code for :blink" do
      ei = EffectInfo.new(:blink)
      assert EffectInfo.to_ansi(ei) == "\e[5m"
    end

    test "returns ANSI code for :reverse" do
      ei = EffectInfo.new(:reverse)
      assert EffectInfo.to_ansi(ei) == "\e[7m"
    end

    test "returns ANSI code for :invert (same as reverse)" do
      ei = EffectInfo.new(:invert)
      assert EffectInfo.to_ansi(ei) == "\e[7m"
    end

    test "returns ANSI code for :hidden" do
      ei = EffectInfo.new(:hidden)
      assert EffectInfo.to_ansi(ei) == "\e[8m"
    end

    test "returns ANSI code for :strikethrough" do
      ei = EffectInfo.new(:strikethrough)
      assert EffectInfo.to_ansi(ei) == "\e[9m"
    end

    test "returns combined ANSI codes for multiple effects" do
      ei = EffectInfo.new([:bold, :underline])
      ansi = EffectInfo.to_ansi(ei)
      assert ansi =~ "1"
      assert ansi =~ "4"
    end

    test "returns combined codes in reverse of input order" do
      ei = EffectInfo.new([:underline, :bold, :italic])
      ansi = EffectInfo.to_ansi(ei)
      assert ansi =~ "1"
      assert ansi =~ "3"
      assert ansi =~ "4"
    end

    test "returns empty string for EffectInfo with only link" do
      ei = EffectInfo.new("https://example.com")
      assert EffectInfo.to_ansi(ei) == ""
    end
  end

  describe "optimal_fg_color/1" do
    test "returns black for white background" do
      result = EffectInfo.optimal_fg_color({255, 255, 255})
      assert result == {0, 0, 0}
    end

    test "returns white for black background" do
      result = EffectInfo.optimal_fg_color({0, 0, 0})
      assert result == {255, 255, 255}
    end

    test "returns black for light gray" do
      result = EffectInfo.optimal_fg_color({200, 200, 200})
      assert result == {0, 0, 0}
    end

    test "returns white for dark gray" do
      result = EffectInfo.optimal_fg_color({50, 50, 50})
      assert result == {255, 255, 255}
    end

    test "returns white for red (low luminance)" do
      result = EffectInfo.optimal_fg_color({255, 0, 0})
      assert result == {255, 255, 255}
    end

    test "returns black for green (high luminance)" do
      result = EffectInfo.optimal_fg_color({0, 255, 0})
      assert result == {0, 0, 0}
    end

    test "returns white for blue (low luminance)" do
      result = EffectInfo.optimal_fg_color({0, 0, 255})
      assert result == {255, 255, 255}
    end

    test "returns black for cyan (high luminance)" do
      result = EffectInfo.optimal_fg_color({0, 255, 255})
      assert result == {0, 0, 0}
    end

    test "threshold at exactly 0.5 uses black" do
      result = EffectInfo.optimal_fg_color({128, 128, 128})
      assert result == {0, 0, 0}
    end

    test "bright yellow returns black" do
      result = EffectInfo.optimal_fg_color({255, 255, 128})
      assert result == {0, 0, 0}
    end
  end

  describe "struct fields" do
    test "has all expected fields" do
      ei = EffectInfo.new()
      assert Map.has_key?(ei, :bold)
      assert Map.has_key?(ei, :dim)
      assert Map.has_key?(ei, :italic)
      assert Map.has_key?(ei, :underline)
      assert Map.has_key?(ei, :blink)
      assert Map.has_key?(ei, :reverse)
      assert Map.has_key?(ei, :invert)
      assert Map.has_key?(ei, :hidden)
      assert Map.has_key?(ei, :strikethrough)
      assert Map.has_key?(ei, :link)
    end
  end
end
