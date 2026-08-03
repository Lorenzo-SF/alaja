defmodule Alaja.TestBackendTest do
  use ExUnit.Case, async: true

  alias Alaja.{Frame, Layout, TestBackend}
  alias Alaja.View.Node

  test "init/1 stores width + height" do
    {:ok, state} = TestBackend.init(width: 40, height: 12)
    assert state.width == 40
    assert state.height == 12
    assert TestBackend.size(state) == {40, 12}
  end

  test "init/1 with default size" do
    {:ok, state} = TestBackend.init([])
    assert state.size == {80, 24}
  end

  test "render/3 stores frame in state" do
    {:ok, state} = TestBackend.init(width: 10, height: 5)
    frame = Frame.new(10, 5)
    {:ok, state} = TestBackend.render(state, frame, nil)
    assert TestBackend.frame(state) == frame
  end

  test "all_frames/1 returns the history newest-first" do
    {:ok, state} = TestBackend.init(width: 4, height: 2)
    f1 = Layout.render_to_frame(Node.text("one"), 4, 2)
    f2 = Layout.render_to_frame(Node.text("two"), 4, 2)
    {:ok, state} = TestBackend.render(state, f1, nil)
    {:ok, state} = TestBackend.render(state, f2, f1)
    assert [^f2, ^f1] = TestBackend.all_frames(state)
  end

  test "frame_text/2 returns row text" do
    {:ok, state} = TestBackend.init(width: 10, height: 2)
    frame = Layout.render_to_frame(Node.text("hi"), 10, 2)
    {:ok, state} = TestBackend.render(state, frame, nil)
    assert TestBackend.frame_text(state, 1) == "hi"
  end

  test "frame_string/1 joins rows" do
    {:ok, state} = TestBackend.init(width: 4, height: 2)
    frame =
      Layout.render_to_frame(
        Node.column([Node.text("hi"), Node.text("ok")]),
        4,
        2
      )

    {:ok, state} = TestBackend.render(state, frame, nil)
    assert TestBackend.frame_string(state) == "hi\nok"
  end

  test "read_event/1 returns no_input (placeholder)" do
    {:ok, state} = TestBackend.init([])
    assert {:error, :no_input} = TestBackend.read_event(state)
  end

  test "shutdown/1 is a no-op" do
    {:ok, state} = TestBackend.init([])
    assert :ok = TestBackend.shutdown(state)
  end

  test "send_msg/2 records the event" do
    {:ok, state} = TestBackend.init([])
    msg = %{key: "x"}
    {:ok, state} = TestBackend.send_msg(state, msg)
    pid = self()
    assert [{^pid, ^msg}] = state.events
  end
end
