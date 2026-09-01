defmodule Alaja.TextTest do
  use ExUnit.Case, async: true

  alias Alaja.Text

  test "empty string has width 0" do
    assert Text.width("") == 0
  end

  test "ASCII printable is width 1 per char" do
    assert Text.width("hello") == 5
    assert Text.width("a") == 1
  end

  test "digits and punctuation" do
    assert Text.width("123") == 3
    assert Text.width("!@#") == 3
  end

  test "CJK is width 2 per char" do
    # Japanese: こんにちは (5 chars, 10 cells)
    assert Text.width("こんにちは") == 10
    # Chinese: 你好 (2 chars, 4 cells)
    assert Text.width("你好") == 4
    # Korean: 안녕 (2 chars, 4 cells)
    assert Text.width("안녕") == 4
  end

  test "control chars are width 0" do
    assert Text.width("\t\n") == 0
  end

  test "mixed ASCII + CJK" do
    # "Hi 你好" = 2 ASCII + 1 space + 2 CJK = 2 + 1 + 4 = 7
    assert Text.width("Hi 你好") == 7
  end

  test "combining marks don't add width" do
    # "a" + combining acute (0x0301) = 1 + 0 = 1
    assert Text.width("a\u0301") == 1
  end
end
