defmodule Alaja.InputTest do
  use ExUnit.Case, async: true

  alias Alaja.{Input, Msg}

  defp keys(input), do: Enum.map(Input.parse(input), & &1.key)

  test "empty input returns empty list" do
    assert Input.parse("") == []
  end

  test "printable ASCII" do
    assert keys("hi") == ["h", "i"]
  end

  test "digits" do
    assert keys("123") == ["1", "2", "3"]
  end

  test "punctuation" do
    assert keys("!@#") == ["!", "@", "#"]
  end

  test "space" do
    assert keys("a b") == ["a", " ", "b"]
  end

  test "enter" do
    assert keys("\r") == ["enter"]
  end

  test "tab" do
    assert keys("\t") == ["tab"]
  end

  test "backspace" do
    assert keys(<<0x7F>>) == ["backspace"]
  end

  test "escape" do
    assert keys(<<0x1B>>) == ["esc"]
  end

  test "ctrl-c" do
    assert keys(<<0x03>>) == ["ctrl-c"]
  end

  test "arrow up" do
    assert keys("\e[A") == ["up"]
  end

  test "arrow down" do
    assert keys("\e[B") == ["down"]
  end

  test "arrow right" do
    assert keys("\e[C") == ["right"]
  end

  test "arrow left" do
    assert keys("\e[D") == ["left"]
  end

  test "home via tilde" do
    assert keys("\e[1~") == ["home"]
  end

  test "end via tilde" do
    assert keys("\e[4~") == ["end"]
  end

  test "pageup via tilde" do
    assert keys("\e[5~") == ["pageup"]
  end

  test "pagedown via tilde" do
    # tilde 6 in xterm is pagedown (some terminals: delete)
    assert keys("\e[6~") == ["pagedown"]
  end

  test "F1 via tilde" do
    assert keys("\e[11~") == ["f1"]
  end

  test "F12 via tilde" do
    assert keys("\e[24~") == ["f12"]
  end

  test "SS3 up" do
    assert keys("\eOA") == ["up"]
  end

  test "SS3 F1" do
    assert keys("\eOP") == ["f1"]
  end

  test "alt-key" do
    assert [msg] = Input.parse("\ea")
    assert msg.key == "a"
    assert :alt in msg.modifiers
  end

  test "shift+tab via tilde" do
    # ESC [ 1;2 Z = shift+tab in xterm
    assert keys("\e[1;2Z") |> Enum.member?("tab")
  end

  test "kitty keyboard protocol" do
    # ESC [ 97 u = just 'a'
    assert keys("\e[97u") == ["a"]
  end

  test "kitty keyboard with ctrl" do
    # ESC [ 97 ; 5 u = ctrl+a (modifier 5)
    assert [msg] = Input.parse("\e[97;5u")
    assert msg.key == "a"
    assert :ctrl in msg.modifiers
  end

  test "resize event" do
    [msg] = Input.parse("\e[8;24;80t")
    assert %Msg.Resize{width: 80, height: 24} = msg
  end

  test "mixed input" do
    parsed = Input.parse("hi\e[A")
    assert length(parsed) == 3
    assert Enum.map(parsed, & &1.key) == ["h", "i", "up"]
  end

  test "returns Msg.t() structs" do
    [%Msg.Key{} = msg] = Input.parse("a")
    assert msg.key == "a"
  end

  test "ignores unknown bytes" do
    assert Input.parse(<<0xFF, 0xFE>>) == []
  end
end
