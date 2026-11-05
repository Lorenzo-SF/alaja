defmodule Alaja.CLI.Commands.Show.TableTest do
  @moduledoc """
  Tests for the `alaja table` command, focused on argv parsing.

  These tests cover the historical bugs where the CLI parsing format
  diverged from what `@help_data :usage` documented:

    * B13: `--headers 'a;b;c'` was split by `,` (now split by `;`).
    * B14: `--rows '1;2;;3;4'` was split by `,` then by `;` (now split
      by `;` per cell, with rows separated by `;;`).
    * B15: `--row-N-effect bold` was accepted as `rows_<n>_effect` (singular)
      but the backend only matches `rows_<n>_effects` (plural). The fix
      normalises singular to plural.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Alaja.CLI.Commands.Show.Table

  # -----------------------------------------------------------------
  # End-to-end smoke tests
  # -----------------------------------------------------------------

  test "renders a simple grid with semicolon-separated headers" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name;status",
          "--rows",
          "api;OK;;db;WARN"
        ])
      end)

    assert output =~ "name"
    assert output =~ "api"
    assert output =~ "db"
  end

  test "renders a single-column header without splitting it" do
    # Without the new spec the legacy `name,status` should now appear as
    # ONE column called "name,status" because `,` is not a separator.
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name,status",
          "--rows",
          "alice"
        ])
      end)

    assert output =~ "name,status"
    assert output =~ "alice"
  end

  test "rows with multiple cells render correctly" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "service;status;uptime",
          "--rows",
          "api;OK;12d;;db;WARN;2h"
        ])
      end)

    assert output =~ "service"
    assert output =~ "uptime"
    assert output =~ "12d"
    assert output =~ "2h"
  end

  test "handles trailing whitespace in headers and rows" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          " name ; status ",
          "--rows",
          " api ; OK ;; db ; WARN "
        ])
      end)

    assert output =~ "name"
    assert output =~ "status"
    assert output =~ "api"
    assert output =~ "db"
  end

  test "literal semicolon inside a cell via \\;" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name;note",
          "--rows",
          "alice;ok\\;on-call;;bob;warn\\;backup"
        ])
      end)

    assert output =~ "ok;on-call"
    assert output =~ "warn;backup"
  end

  # -----------------------------------------------------------------
  # Regression tests for the historical bugs
  # -----------------------------------------------------------------

  test "B13 regression: --headers split by `;`, not `,`" do
    output =
      capture_io(fn ->
        Table.run(["--headers", "a;b;c", "--rows", "1;2;3;;4;5;6"])
      end)

    assert output =~ "a"
    assert output =~ "b"
    assert output =~ "c"
  end

  test "B14 regression: --rows cells split by `;`" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "x;y",
          "--rows",
          "1;2;;3;4;;5;6"
        ])
      end)

    assert output =~ "1"
    assert output =~ "2"
    assert output =~ "3"
    assert output =~ "4"
    assert output =~ "5"
    assert output =~ "6"
  end

  test "B15 regression: --row-N-effects (plural) is accepted and applied" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name;status",
          "--rows",
          "api;OK;;db;WARN",
          "--row-1-effects",
          "bold",
          "--row-2-effects",
          "dim"
        ])
      end)

    assert output =~ "api"
    assert output =~ "db"
    assert output =~ "OK"
    assert output =~ "WARN"
  end

  test "B15 backwards-compat: --row-N-effect (singular) still accepted" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name;status",
          "--rows",
          "api;OK",
          "--row-1-effect",
          "bold"
        ])
      end)

    assert output =~ "api"
    assert output =~ "OK"
  end
end
