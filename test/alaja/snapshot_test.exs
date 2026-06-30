defmodule Alaja.SnapshotTest do
  @moduledoc """
  Regression tests that compare component render output against the
  golden snapshots captured before the Cell/Buffer refactor.

  Each test loads `<snapshot_name>.snap` from `test/snapshots/` and
  asserts that the corresponding component's `render/N` produces the
  same bytes (after `IO.iodata_to_binary`).
  """

  use ExUnit.Case, async: true

  alias Alaja.Components.{
    Bar,
    Box,
    Breadcrumbs,
    Header,
    Json,
    Separator,
    Table
  }

  @snapshot_dir "test/snapshots"

  defp load_snapshot(name) do
    path = Path.join(@snapshot_dir, "#{name}.snap")
    File.read!(path)
  end

  defp assert_snapshot(name, actual) do
    path = Path.join(@snapshot_dir, "#{name}.snap")

    if File.exists?(path) do
      expected = File.read!(path)

      cond do
        expected == actual ->
          :ok

        System.get_env("UPDATE_SNAPSHOTS") == "1" ->
          File.write!(path, actual)
          :ok

        true ->
          flunk(
            "Snapshot mismatch for #{name}.\n" <>
              "Expected (#{byte_size(expected)} bytes): #{inspect(expected)}\n" <>
              "Actual   (#{byte_size(actual)} bytes): #{inspect(actual)}"
          )
      end
    else
      File.mkdir_p!(@snapshot_dir)
      File.write!(path, actual)
      :ok
    end
  end

  defp to_binary(%Alaja.Buffer{} = buffer),
    do: Alaja.Buffer.to_iodata(buffer) |> IO.iodata_to_binary()

  defp to_binary(other) when is_list(other) or is_binary(other), do: IO.iodata_to_binary(other)

  describe "Separator snapshots" do
    test "default" do
      actual = Separator.render() |> to_binary()
      assert actual == load_snapshot("separator_default")
    end

    test "with text" do
      actual =
        Separator.render("HELLO", char: "━", color: {0, 180, 216}, width: 40)
        |> to_binary()

      assert actual == load_snapshot("separator_with_text")
    end

    test "thin" do
      actual = Separator.render(nil, char: "─", width: 30) |> to_binary()
      assert actual == load_snapshot("separator_thin")
    end
  end

  describe "Bar snapshots" do
    test "50%" do
      actual = Bar.render(50, 100, label: "CPU", width: 20) |> to_binary()
      assert actual == load_snapshot("bar_50")
    end

    test "75%" do
      actual = Bar.render(75, 100, label: "Upload", width: 40) |> to_binary()
      assert actual == load_snapshot("bar_75")
    end

    test "0%" do
      actual = Bar.render(0, 100, width: 10) |> to_binary()
      assert actual == load_snapshot("bar_0")
    end

    test "100%" do
      actual = Bar.render(100, 100, width: 10) |> to_binary()
      assert actual == load_snapshot("bar_100")
    end
  end

  describe "Breadcrumbs snapshots" do
    test "three items" do
      actual = Breadcrumbs.render(["Home", "Projects", "Zaguan"], []) |> to_binary()
      assert actual == load_snapshot("breadcrumbs")
    end

    test "two items" do
      actual = Breadcrumbs.render(["A", "B"], []) |> to_binary()
      assert actual == load_snapshot("breadcrumbs_short")
    end
  end

  describe "Header snapshots" do
    test "small" do
      actual = Header.render("Title") |> to_binary()
      assert actual == load_snapshot("header_small")
    end

    test "medium with subtitle" do
      actual = Header.render("Title", subtitle: "Subtitle here") |> to_binary()
      assert actual == load_snapshot("header_medium")
    end

    test "large" do
      actual = Header.render("Title", size: :large, color: {255, 87, 51}) |> to_binary()
      assert actual == load_snapshot("header_large")
    end
  end

  describe "Box snapshots" do
    test "default with title" do
      actual = Box.render("Hello, world!", title: "Greeting") |> to_binary()
      assert actual == load_snapshot("box_default")
    end

    test "no title" do
      actual = Box.render(["Line 1", "Line 2"], border: :rounded, padding: 2) |> to_binary()
      assert actual == load_snapshot("box_no_title")
    end

    test "double border" do
      actual =
        Box.render("Content", border: :double, border_color: {72, 187, 120})
        |> to_binary()

      assert actual == load_snapshot("box_double")
    end
  end

  describe "Json snapshots" do
    test "simple map" do
      actual = Json.render(%{name: "Alaja", version: "0.2.0"}) |> to_binary()
      assert_snapshot("json_simple", actual)
    end

    test "nested map" do
      actual =
        Json.render(%{deps: ["pote", "jason"], meta: %{author: "Lorenzo", count: 3}})
        |> to_binary()

      assert_snapshot("json_nested", actual)
    end
  end

  describe "Table snapshots" do
    test "simple table with rounded border" do
      actual =
        Table.render(
          [
            ["Service", "Status", "Uptime"],
            ["api", "OK", "12d"],
            ["db", "OK", "30d"],
            ["cache", "WARN", "2h"]
          ],
          headers_color: :cyan,
          headers_effects: [:bold],
          rows_2_color: [:white, :yellow, :white],
          table_border: :rounded
        )
        |> to_binary()

      assert actual == load_snapshot("table_simple")
    end
  end
end
