defmodule Alaja.CLI.Smoke.MessageBoxTest do
  @moduledoc """
  Smoke test for the `alaja message --chunk ... --box` flow.

  This test reproduces the bug reported by user:

      alaja message \
        --chunk "[|color:gray" \
        --chunk "OK|color:green|bold:true" \
        --chunk "] Deployed|color:cyan" \
        --align center \
        --box \
        --box-border rounded \
        --box-color "#00B4D8"

  Expected: box width hugs the content (~14 chars + padding).
  Bug: box becomes too wide because Box.render is given the flattened
  ANSI string and counts escape codes as characters.
  """
  use Alaja.SmokeCase, async: false

  @test_name "message_box_test.exs::rounded box hugs content"

  test "rounded box hugs content with colored chunks" do
    {output, _stderr, exit_code} =
      run_cli([
        "message",
        "--chunk", "[|color:gray",
        "--chunk", "OK|color:green|bold:true",
        "--chunk", "] Deployed|color:cyan",
        "--align", "center",
        "--box",
        "--box-border", "rounded",
        "--box-color", "#00B4D8"
      ])

    assert exit_code == 0, "CLI should not crash. Output:\n#{output}"

    assert_snapshot(@test_name, output, snapshot: "message_box_rounded")
  end

  test "single border box hugs content" do
    {output, _stderr, exit_code} =
      run_cli([
        "message",
        "--text", "Hello",
        "--color", "green",
        "--align", "center",
        "--box",
        "--box-border", "single"
      ])

    assert exit_code == 0, "CLI should not crash. Output:\n#{output}"

    assert_snapshot(@test_name <> "_single", output, snapshot: "message_box_single")
  end

  test "box without chunks renders plain text" do
    {output, _stderr, exit_code} =
      run_cli([
        "message",
        "--text", "Plain text inside box",
        "--box"
      ])

    assert exit_code == 0, "CLI should not crash. Output:\n#{output}"

    assert_snapshot(@test_name <> "_plain", output, snapshot: "message_box_plain")
  end
end