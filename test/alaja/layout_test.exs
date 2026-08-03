defmodule Alaja.LayoutTest do
  use ExUnit.Case, async: true

  alias Alaja.{Layout, Frame}
  alias Alaja.View.Node

  test "measure of text is length x 1" do
    assert Layout.measure(Node.text("hello"), %{width: 80, height: 24}) == {5, 1}
  end

  test "measure of column stacks children" do
    node = Node.column([Node.text("a"), Node.text("b")])
    assert Layout.measure(node, %{width: 80, height: 24}) == {1, 2}
  end

  test "measure of row places children side by side" do
    node = Node.row([Node.text("hello"), Node.text("world")])
    assert Layout.measure(node, %{width: 80, height: 24}) == {10, 1}
  end

  test "measure of row with gap" do
    node = Node.row([Node.text("a"), Node.text("b")], gap: 2)
    assert Layout.measure(node, %{width: 80, height: 24}) == {1 + 2 + 1, 1}
  end

  test "measure of box adds padding and border" do
    node = Node.box(Node.text("hi"), border: :single, padding: 1)
    assert Layout.measure(node, %{width: 80, height: 24}) == {2 + 2 + 2, 1 + 2 + 2}
  end

  test "measure of grid with 2 columns" do
    node = Node.grid([Node.text("a"), Node.text("b"), Node.text("c"), Node.text("d")], columns: 2)
    assert Layout.measure(node, %{width: 80, height: 24}) == {2, 2}
  end

  test "render_to_frame/3 places text at row 1" do
    node = Node.text("hi")
    f = Layout.render_to_frame(node, 10, 3)
    assert Frame.row_text(f, 1) == "hi"
  end

  test "render_to_frame/3 with column stacks children vertically" do
    node = Node.column([Node.text("a"), Node.text("b")])
    f = Layout.render_to_frame(node, 10, 5)
    assert Frame.row_text(f, 1) == "a"
    assert Frame.row_text(f, 2) == "b"
  end

  test "render_to_frame/3 with box draws border" do
    node = Node.box(Node.text("x"), border: :single)
    f = Layout.render_to_frame(node, 5, 3)
    assert Frame.row_text(f, 1) =~ "┌"
    assert Frame.row_text(f, 3) =~ "└"
  end

  test "render_to_frame/3 with rule draws horizontal line" do
    node = Node.column([Node.text("hi"), Node.rule()])
    f = Layout.render_to_frame(node, 5, 4)
    # rule fills the column width (5) — like <hr> in CSS
    assert Frame.row_text(f, 2) == "─────"
  end

  test "render_to_frame/3 with status_bar anchors to last row" do
    node = Node.column([Node.text("hi"), Node.status_bar("status")])
    f = Layout.render_to_frame(node, 20, 5)
    assert Frame.row_text(f, 5) == "status"
  end

  test "flex distribution in column" do
    node = Node.column([Node.text("a", flex: 1), Node.text("b", flex: 3)])
    f = Layout.render_to_frame(node, 4, 6)
    # flex distribution: total flex=4, free=4
    #   "a" gets 1 + div(1*4, 4) = 2 rows, "b" gets 1 + div(3*4, 4) = 4 rows
    # text is rendered at the top of its region
    assert Frame.row_text(f, 1) == "a"
    assert Frame.row_text(f, 3) == "b"
  end
end
