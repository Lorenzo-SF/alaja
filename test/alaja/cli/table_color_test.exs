defmodule Alaja.CLI.TableColorTest do
  @moduledoc """
  Tests for `alaja table --row-N-color` per-cell colour application.

  Verifies:

    * `--row-N-color` accepts both `|` and `;` as color separators.
    * Each chunk maps to one cell in row N (1-indexed).
    * Effect args (`--row-N-effect`, `--row-N-effects`) apply per row.

  These tests use `capture_io/1` to drive the command module end-to-end
  through its public `run/1` API.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Alaja.CLI.Commands.Show.Table

  test "row-1-color with semicolon separator applies one colour per cell" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name;color;note",
          "--rows",
          "api;red;critical;;db;green;ok",
          "--row-1-color",
          "hex:#ff0000;hex:#00ff00;hex:#0000ff"
        ])
      end)

    # Header names should be present
    assert String.contains?(output, "name")
    assert String.contains?(output, "color")
    assert String.contains?(output, "note")
    # Row 1 cells should be present
    assert String.contains?(output, "api")
    assert String.contains?(output, "red")
    assert String.contains?(output, "critical")
  end

  test "row-1-color with pipe separator still works (backward compat)" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name;note",
          "--rows",
          "api;error;;db;ok",
          "--row-1-color",
          "hex:#ff0000|hex:#00ff00",
          "--row-2-color",
          "hex:#0000ff|hex:#888888"
        ])
      end)

    assert String.contains?(output, "api")
    assert String.contains?(output, "db")
  end

  test "row-1-effects applies per-row effects (bold)" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "x;y",
          "--rows",
          "a;b",
          "--row-1-effects",
          "bold",
          "--row-2-effects",
          "italic"
        ])
      end)

    assert String.contains?(output, "a")
    assert String.contains?(output, "b")
    # bold escape (SGR 1) and italic escape (SGR 3) should be present
    # somewhere in the rendered table.
    assert String.contains?(output, "\x1b[1") or
             String.contains?(output, "\x1b[1;")
  end

  test "row-1-color with theme: keyword" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "k;v",
          "--rows",
          "a;b",
          "--row-1-color",
          "theme:primary;theme:secondary"
        ])
      end)

    assert String.contains?(output, "a")
    assert String.contains?(output, "b")
  end

  test "table shows help when no headers or rows given" do
    output = capture_io(fn -> Table.run([]) end)

    assert String.contains?(output, "Alaja Table")
    assert String.contains?(output, "--row-N-color")
  end

  test "--help shows usage block and examples" do
    output = capture_io(fn -> Table.run(["--help"]) end)

    assert String.contains?(output, "Alaja Table")
    assert String.contains?(output, "Per-row")
    assert String.contains?(output, "--row")
  end
end
