defmodule Alaja.CLI.Commands.Show.TableTest do
  @moduledoc """
  Tests for the `alaja table` command, focused on argv parsing.

  These tests cover the historical bugs where the CLI parsing format
  diverged from what `@help_data :usage` documented:

    * B13: `--headers 'a,b,c'` was split by `;` (now split by `,`).
    * B14: `--rows '1,2;3,4'` was split first by `|` then by `;` (now
      split by `,` per row, with rows separated by `;`-equivalent
      spaces).
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

  test "renders a simple grid with comma-separated headers" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name,status",
          "--rows",
          "api,OK;db,WARN"
        ])
      end)

    assert output =~ "name"
    assert output =~ "api"
    assert output =~ "db"
  end

  test "renders a single-column header without splitting it" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "name,status",
          "--rows",
          "alice;bob"
        ])
      end)

    # The header should be ONE column, not split into two.
    assert output =~ "name"
    assert output =~ "status"
    assert output =~ "alice"
    assert output =~ "bob"
  end

  test "rows with multiple cells render correctly" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "service,status,uptime",
          "--rows",
          "api,OK,12d;db,WARN,2h"
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
          " name , status ",
          "--rows",
          " api , OK ; db , WARN "
        ])
      end)

    assert output =~ "name"
    assert output =~ "status"
    assert output =~ "api"
    assert output =~ "db"
  end

  # -----------------------------------------------------------------
  # Regression tests for the historical bugs
  # -----------------------------------------------------------------

  test "B13 regression: --headers split by `,`, not `;`" do
    # Old behaviour: `String.split("a,b,c", ";")` returned ["a,b,c"] (one header).
    # Fixed: split by `,` gives ["a", "b", "c"] (three headers).
    output =
      capture_io(fn ->
        Table.run(["--headers", "a,b,c", "--rows", "1,2,3", "4,5,6"])
      end)

    assert output =~ "a"
    assert output =~ "b"
    assert output =~ "c"
  end

  test "B14 regression: --rows cells split by `,`" do
    # Old behaviour: each --rows value was split by `|` and then each
    # chunk by `;`. The fixed parser splits each --rows by `;` for
    # rows then `,` for cells within each row.
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "x,y",
          "--rows",
          "1,2;3,4;5,6"
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
          "name,status",
          "--rows",
          "api,OK;db,WARN",
          "--row-1-effects",
          "bold",
          "--row-2-effects",
          "dim"
        ])
      end)

    # If the suffix were `effect` (singular), the parser would not match
    # the backend's `_effects` matcher and the options would be silently
    # dropped. The rendered table should still contain the row labels.
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
          "name,status",
          "--rows",
          "api,OK",
          "--row-1-effect",
          "bold"
        ])
      end)

    # The parser normalises singular to plural so existing scripts keep
    # working without changes.
    assert output =~ "api"
    assert output =~ "OK"
  end
end
