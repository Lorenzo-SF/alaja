defmodule Alaja.FocusManagerTest do
  use ExUnit.Case, async: true

  alias Alaja.FocusManager

  test "new creates focus with first id focused" do
    fm = FocusManager.new([:a, :b, :c])
    assert FocusManager.focused(fm) == :a
  end

  test "focused? returns true for current, false otherwise" do
    fm = FocusManager.new([:a, :b, :c])
    assert FocusManager.focused?(fm, :a)
    refute FocusManager.focused?(fm, :b)
  end

  test "focus sets a specific id" do
    fm = FocusManager.new([:a, :b, :c]) |> FocusManager.focus(:b)
    assert FocusManager.focused(fm) == :b
  end

  test "focus ignores unknown ids" do
    fm = FocusManager.new([:a, :b])
    assert FocusManager.focused(fm) == :a
    fm2 = FocusManager.focus(fm, :unknown)
    assert FocusManager.focused(fm2) == :a
  end

  test "next rotates" do
    fm = FocusManager.new([:a, :b, :c]) |> FocusManager.next()
    assert FocusManager.focused(fm) == :b
    fm2 = fm |> FocusManager.next() |> FocusManager.next()
    assert FocusManager.focused(fm2) == :a  # wrap
  end

  test "prev rotates" do
    fm = FocusManager.new([:a, :b, :c]) |> FocusManager.prev()
    assert FocusManager.focused(fm) == :c  # wrap
  end

  test "empty manager returns nil focused" do
    assert FocusManager.focused(FocusManager.new([])) == nil
  end
end
