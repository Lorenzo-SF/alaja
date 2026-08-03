defmodule Alaja.ComponentsTest do
  use ExUnit.Case, async: true

  alias Alaja.Components
  alias Alaja.Components.{ListState, TabsState, LogState, ProgressState}
  alias Alaja.Msg

  describe "list" do
    test "init creates state" do
      s = Components.list_init(["a", "b", "c"])
      assert s.items == ["a", "b", "c"]
      assert s.selected == 0
      assert s.offset == 0
    end

    test "up arrow decrements selected" do
      s = Components.list_init(["a", "b", "c"]) |> then(&%{&1 | selected: 1})
      {:ok, s2, []} = Components.list_update(s, Msg.key("up"))
      assert s2.selected == 0
    end

    test "up arrow stops at 0" do
      s = Components.list_init(["a", "b", "c"])
      {:ok, s2, []} = Components.list_update(s, Msg.key("up"))
      assert s2.selected == 0
    end

    test "down arrow increments selected" do
      s = Components.list_init(["a", "b", "c"])
      {:ok, s2, []} = Components.list_update(s, Msg.key("down"))
      assert s2.selected == 1
    end

    test "down arrow stops at last item" do
      s = Components.list_init(["a"]) |> then(&%{&1 | selected: 0})
      {:ok, s2, []} = Components.list_update(s, Msg.key("down"))
      assert s2.selected == 0
    end

    test "view returns a column" do
      s = Components.list_init(["a", "b", "c"])
      view = Components.list_view(s)
      assert match?(%Alaja.View.Node{tag: :column}, view)
    end
  end

  describe "tabs" do
    test "init creates state" do
      s = Components.tabs_init(["one", "two", "three"])
      assert s.labels == ["one", "two", "three"]
      assert s.active == 0
    end

    test "right rotates" do
      s = Components.tabs_init(["a", "b", "c"])
      {:ok, s2, []} = Components.tabs_update(s, Msg.key("right"))
      assert s2.active == 1
    end

    test "right wraps" do
      s = Components.tabs_init(["a", "b"]) |> then(&%{&1 | active: 1})
      {:ok, s2, []} = Components.tabs_update(s, Msg.key("right"))
      assert s2.active == 0
    end

    test "left rotates" do
      s = Components.tabs_init(["a", "b", "c"]) |> then(&%{&1 | active: 1})
      {:ok, s2, []} = Components.tabs_update(s, Msg.key("left"))
      assert s2.active == 0
    end

    test "view returns a row" do
      s = Components.tabs_init(["a", "b"])
      view = Components.tabs_view(s)
      assert match?(%Alaja.View.Node{tag: :row}, view)
    end
  end

  describe "log" do
    test "init creates state" do
      s = Components.log_init([])
      assert s.lines == []
    end

    test "append adds line" do
      s = Components.log_init([])
      s2 = Components.log_append(s, "hello")
      assert s2.lines == ["hello"]
    end

    test "append respects max_lines" do
      s = Components.log_init(max_lines: 3)
      s2 = s |> Components.log_append("a") |> Components.log_append("b") |> Components.log_append("c") |> Components.log_append("d")
      assert s2.lines == ["b", "c", "d"]
    end

    test "view returns a column" do
      s = Components.log_init([]) |> Components.log_append("a")
      view = Components.log_view(s)
      assert match?(%Alaja.View.Node{tag: :column}, view)
    end
  end

  describe "progress" do
    test "init creates state" do
      s = Components.progress_init(current: 0, total: 100, width: 10)
      assert s.current == 0
      assert s.total == 100
      assert s.width == 10
    end

    test "set clamps to range" do
      s = Components.progress_init(total: 100)
      assert Components.progress_set(s, -5).current == 0
      assert Components.progress_set(s, 50).current == 50
      assert Components.progress_set(s, 200).current == 100
    end

    test "view contains bar" do
      s = Components.progress_init(current: 50, total: 100, width: 10)
      view = Components.progress_view(s)
      assert match?(%Alaja.View.Node{tag: :text}, view)
    end
  end
end
