defmodule Alaja.CLI.Smoke.AnimatedBarKittTest do
  @moduledoc """
  Smoke test for `alaja animated-bar --type kitt`.

  User reported:

      alaja animated-bar 60 --type kitt --animation-color red

  Expected: animation runs cleanly without overlapping previous frames.
  Bug: frames print on the same lines, mixing with shell prompt because
  the cursor escape only clears the current line.
  """
  use Alaja.CLI.Smoke.Case, async: false

  @test_name "animated_bar_kitt_test.exs::kitt animation"

  test "kitt animation produces clean output" do
    # We use a small value to keep the test fast.
    # The animation runs once and exits.
    {output, _stderr, exit_code} =
      run_cli([
        "animated-bar",
        "10",
        "--type", "kitt",
        "--animation-color", "red",
        "--duration", "500"
      ])

    assert exit_code == 0, "CLI should not crash. Output:\n#{output}"

    assert_snapshot(@test_name, output, snapshot: "animated_bar_kitt")
  end

  test "kitt animation with box" do
    {output, _stderr, exit_code} =
      run_cli([
        "animated-bar",
        "10",
        "--type", "kitt",
        "--animation-color", "cyan",
        "--duration", "500",
        "--box",
        "--box-border", "rounded"
      ])

    assert exit_code == 0, "CLI should not crash. Output:\n#{output}"

    assert_snapshot(@test_name <> "_with_box", output, snapshot: "animated_bar_kitt_box")
  end
end