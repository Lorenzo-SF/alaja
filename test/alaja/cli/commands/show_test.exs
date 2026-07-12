defmodule ShowTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Alaja.CLI.Commands.Show.Header

  test "header command renders a title" do
    output = capture_io(fn -> Header.run(["Dashboard"]) end)
    assert String.contains?(output, "Dashboard")
  end

  test "header command renders subtitle when provided" do
    output = capture_io(fn -> Header.run(["Dashboard", "--subtitle", "Test"]) end)
    assert String.contains?(output, "Test")
  end
end
