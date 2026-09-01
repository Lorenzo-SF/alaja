defmodule Alaja.Text do
  @moduledoc """
  Text utilities for alaja 3.0.

  `width/1` returns the visible cell-width of a string. ASCII
  characters have width 1, CJK characters have width 2, and zero-width
  joiners and combining characters have width 0. This is the same
  width that a terminal would render the string at.
  """

  @doc """
  Returns the visible cell-width of a string.

  Uses a simple but correct algorithm:

    * ASCII printable (0x20-0x7E): width 1
    * Control chars (0x00-0x1F, 0x7F): width 0
    * Zero-width joiners (U+200D), combining marks, format chars: width 0
    * CJK ranges (CJK Unified, Hiragana, Katakana, fullwidth): width 2
    * Everything else: width 1

  This is a simplified East Asian Width implementation. It is fast
  and good enough for TUI layout. For full Unicode compliance use
  the `:ex_unicode` or `:string_width` packages.
  """
  @spec width(String.t()) :: non_neg_integer()
  def width(""), do: 0

  def width(string) when is_binary(string) do
    string
    |> String.to_charlist()
    |> Enum.reduce(0, fn codepoint, acc ->
      acc + char_width(codepoint)
    end)
  end

  defp char_width(c) when c in 0x00..0x1F, do: 0
  defp char_width(0x7F), do: 0
  defp char_width(c) when c >= 0x20 and c <= 0x7E, do: 1
  # Zero-width joiner
  defp char_width(0x200D), do: 0
  # Variation selectors
  defp char_width(c) when c in 0xFE00..0xFE0F, do: 0
  # Combining diacritical marks
  defp char_width(c) when c in 0x0300..0x036F, do: 0
  # Combining diacritical marks extended
  defp char_width(c) when c in 0x1AB0..0x1AFF, do: 0
  defp char_width(c) when c in 0x1DC0..0x1DFF, do: 0
  defp char_width(c) when c in 0x20D0..0x20FF, do: 0
  defp char_width(c) when c in 0xFE20..0xFE2F, do: 0
  # CJK Unified Ideographs
  defp char_width(c) when c in 0x4E00..0x9FFF, do: 2
  # CJK Unified Ideographs Extension A
  defp char_width(c) when c in 0x3400..0x4DBF, do: 2
  # CJK Unified Ideographs Extension B-F
  defp char_width(c) when c in 0x20000..0x2A6DF, do: 2
  defp char_width(c) when c in 0x2A700..0x2B73F, do: 2
  defp char_width(c) when c in 0x2B740..0x2B81F, do: 2
  defp char_width(c) when c in 0x2B820..0x2CEAF, do: 2
  # CJK Compatibility Ideographs
  defp char_width(c) when c in 0xF900..0xFAFF, do: 2
  # Hiragana + Katakana
  defp char_width(c) when c in 0x3040..0x30FF, do: 2
  # Hangul Syllables
  defp char_width(c) when c in 0xAC00..0xD7A3, do: 2
  # Hangul Jamo
  defp char_width(c) when c in 0x1100..0x115F, do: 2
  defp char_width(c) when c in 0xA960..0xA97C, do: 2
  # Fullwidth Forms
  defp char_width(c) when c in 0xFF00..0xFF60, do: 2
  defp char_width(c) when c in 0xFFE0..0xFFE6, do: 2
  # Default
  defp char_width(_), do: 1
end
