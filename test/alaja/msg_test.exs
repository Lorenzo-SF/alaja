defmodule Alaja.MsgTest do
  use ExUnit.Case, async: true

  alias Alaja.Msg

  test "key/2 builds a Key event" do
    msg = Msg.key("q", modifiers: [:ctrl], raw: <<3>>)
    assert msg.key == "q"
    assert msg.modifiers == [:ctrl]
    assert msg.raw == <<3>>
  end

  test "mouse/4 builds a Mouse event" do
    msg = Msg.mouse(:press, :left, 10, 20)
    assert msg.action == :press
    assert msg.button == :left
    assert msg.x == 10
    assert msg.y == 20
  end

  test "resize/2 builds a Resize event" do
    msg = Msg.resize(80, 24)
    assert msg.width == 80
    assert msg.height == 24
  end

  test "tick/0 and quit/0" do
    assert %Msg.Tick{} = Msg.tick()
    assert %Msg.Quit{} = Msg.quit()
  end

  test "custom/2" do
    msg = Msg.custom(:foo, %{bar: 1})
    assert msg.name == :foo
    assert msg.payload == %{bar: 1}
  end

  test "mouse rejects invalid coordinates" do
    assert_raise FunctionClauseError, fn -> Msg.mouse(:press, :left, 0, 10) end
    assert_raise FunctionClauseError, fn -> Msg.mouse(:press, :left, 10, 0) end
  end

  test "resize rejects invalid dimensions" do
    assert_raise FunctionClauseError, fn -> Msg.resize(0, 24) end
    assert_raise FunctionClauseError, fn -> Msg.resize(80, 0) end
  end
end
