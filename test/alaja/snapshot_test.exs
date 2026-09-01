defmodule Alaja.SnapshotTest do
  @moduledoc """
  Regression tests that compare component render output against the
  golden snapshots captured before the Cell/Buffer refactor.

  Each test loads `<snapshot_name>.snap` from `test/snapshots/` and
  asserts that the corresponding component's `render/N` produces the
  same bytes (after `IO.iodata_to_binary`).

  Snapshots are deterministic only if the active theme is fixed —
  otherwise the colours used by each component render would vary with
  whichever theme the user has selected. We pin `:catppuccin` here
  because that's the theme that produced the original snapshots.
  """

  use ExUnit.Case, async: false

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
  @pinned_theme "catppuccin"

  setup do
    # Force a deterministic theme for the duration of every snapshot test.
    # Without this the user's active theme (e.g. dracula) changes the
    # 24-bit RGB sequences in the rendered output and every snapshot
    # mismatch fails.
    original = Alaja.Config.get(:theme_active)
    Alaja.Config.set(:theme_active, @pinned_theme)
    on_exit(fn -> Alaja.Config.set(:theme_active, original) end)
    :ok
  end

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
      assert_snapshot("separator_default", actual)
    end

    test "with text" do
      actual =
        Separator.render("HELLO", char: "━", color: {0, 180, 216}, width: 40)
        |> to_binary()

      assert_snapshot("separator_with_text", actual)
    end

    test "thin" do
      actual = Separator.render(nil, char: "─", width: 30) |> to_binary()
      assert_snapshot("separator_thin", actual)
    end
  end

  describe "Bar snapshots" do
    test "50%" do
      actual = Bar.render(50, 100, label: "CPU", width: 20) |> to_binary()
      assert_snapshot("bar_50", actual)
    end

    test "75%" do
      actual = Bar.render(75, 100, label: "Upload", width: 40) |> to_binary()
      assert_snapshot("bar_75", actual)
    end

    test "0%" do
      actual = Bar.render(0, 100, width: 10) |> to_binary()
      assert_snapshot("bar_0", actual)
    end

    test "100%" do
      actual = Bar.render(100, 100, width: 10) |> to_binary()
      assert_snapshot("bar_100", actual)
    end
  end

  describe "Breadcrumbs snapshots" do
    test "three items" do
      actual = Breadcrumbs.render(["Home", "Projects", "Zaguan"], []) |> to_binary()
      assert_snapshot("breadcrumbs", actual)
    end

    test "two items" do
      actual = Breadcrumbs.render(["A", "B"], []) |> to_binary()
      assert_snapshot("breadcrumbs_short", actual)
    end
  end

  describe "Header snapshots" do
    test "small" do
      actual = Header.render("Title") |> to_binary()
      assert_snapshot("header_small", actual)
    end

    test "medium with subtitle" do
      actual = Header.render("Title", subtitle: "Subtitle here") |> to_binary()
      assert_snapshot("header_medium", actual)
    end

    test "large" do
      actual = Header.render("Title", size: :large, color: {255, 87, 51}) |> to_binary()
      assert_snapshot("header_large", actual)
    end
  end

  describe "Box snapshots" do
    test "default with title" do
      actual = Box.render("Hello, world!", title: "Greeting") |> to_binary()
      assert_snapshot("box_default", actual)
    end

    test "no title" do
      actual = Box.render(["Line 1", "Line 2"], border: :rounded, padding: 2) |> to_binary()
      assert_snapshot("box_no_title", actual)
    end

    test "double border" do
      actual =
        Box.render("Content", border: :double, border_color: {72, 187, 120})
        |> to_binary()

      assert_snapshot("box_double", actual)
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

      assert_snapshot("table_simple", actual)
    end
  end
end
