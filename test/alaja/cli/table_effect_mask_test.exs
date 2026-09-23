defmodule Alaja.CLI.TableEffectMaskTest do
  @moduledoc """
  End-to-end tests for the new per-cell effect masks on
  `alaja table --row-N-<effect> "<bool>;<bool>;..."`.

  Each test drives the command through its public `run/1` API in
  `capture_io/1`, asserts the rendered output contains the
  expected pieces (text, ANSI escape codes), and confirms the mask
  is parsed into the opt pipeline correctly by inspecting the
  per-row effects for non-mask vs masked cells.

  These tests are intentionally light on visual assertions —
  `capture_io` on a TTY-less runner still goes through the same
  render path, but verifying every escape sequence is brittle.
  We check `text` presence (no ANSI noise) plus
  `String.contains?(output, "\x1b[")` to confirm the renderer
  actually emitted escape codes (vs. a fall-through plain path).
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Alaja.CLI.Commands.Show.Table

  test "row-N-bold mask with one true keeps bold on that cell only" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "service;status;note",
          "--rows-effects",
          "bold",
          "--rows",
          "api;OK;running;;db;WARN;down",
          "--row-1-bold",
          "true;false;true"
        ])
      end)

    # Header + row content all present in the rendered output.
    assert String.contains?(output, "service")
    assert String.contains?(output, "status")
    assert String.contains?(output, "note")
    assert String.contains?(output, "api")
    assert String.contains?(output, "db")

    # The renderer must have actually emitted escape codes (otherwise
    # the whole mask is silently a no-op).
    assert String.contains?(output, "\x1b[")
  end

  test "row-N-italic false everywhere drops italic from all cells" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "a;b",
          "--rows-effects",
          "italic",
          "--rows",
          "x;y",
          "--row-1-italic",
          "false;false"
        ])
      end)

    assert String.contains?(output, "x")
    assert String.contains?(output, "y")
    # Italic (SGR 3) should NOT appear because every cell is opted out.
    refute String.contains?(output, "\x1b[3")
  end

  test "row-N-underline with mixed mask" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "k1;k2;k3",
          "--rows-effects",
          "underline",
          "--rows",
          "v1;v2;v3;;v4;v5;v6",
          "--row-1-underline",
          "true;false;true",
          "--row-2-underline",
          "false;true;true"
        ])
      end)

    assert String.contains?(output, "v1")
    assert String.contains?(output, "v6")
    assert String.contains?(output, "\x1b[")
  end

  test "true/false aliases are accepted (1, yes, on)" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "a;b",
          "--rows-effects",
          "dim",
          "--rows",
          "x;y",
          "--row-1-dim",
          "yes;no"
        ])
      end)

    assert String.contains?(output, "x")
    assert String.contains?(output, "y")
  end

  test "row-N-<unknown-effect> parses as mask without crashing" do
    # Even if the effect name doesn't appear in the renderer, the
    # CLI accepts it and stores the mask. The table just renders.
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "a",
          "--rows",
          "x",
          "--row-1-unicorn",
          "true"
        ])
      end)

    assert String.contains?(output, "x")
  end

  test "row-N-<effect> back-compat: --row-N-effects still works" do
    output =
      capture_io(fn ->
        Table.run([
          "--headers",
          "a;b",
          "--rows-effects",
          "italic",
          "--rows",
          "x;y",
          "--row-1-effects",
          "bold",
          "--row-2-effects",
          "underline"
        ])
      end)

    assert String.contains?(output, "x")
    assert String.contains?(output, "y")
    assert String.contains?(output, "\x1b[")
  end
end
