defmodule ShowTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Alaja.CLI.Commands.Show.Bar
  alias Alaja.CLI.Commands.Show.Breadcrumbs
  alias Alaja.CLI.Commands.Show.Gradient
  alias Alaja.CLI.Commands.Show.Header
  alias Alaja.CLI.Commands.Show.Json
  alias Alaja.CLI.Commands.Show.List
  alias Alaja.CLI.Commands.Show.Message
  alias Alaja.CLI.Commands.Show.Separator

  test "header command renders a title" do
    output = capture_io(fn -> Header.run(["Dashboard"]) end)
    assert String.contains?(output, "Dashboard")
  end

  test "header command renders subtitle when provided" do
    output = capture_io(fn -> Header.run(["Dashboard", "--subtitle", "Test"]) end)
    assert String.contains?(output, "Test")
  end

  test "bar command renders a progress bar with value" do
    output = capture_io(fn -> Bar.run(["50"]) end)
    assert String.contains?(output, "50%")
  end

  test "bar command renders label when provided" do
    output = capture_io(fn -> Bar.run(["50", "--label", "Progress"]) end)
    assert String.contains?(output, "Progress")
  end

  test "separator command renders a separator line" do
    output = capture_io(fn -> Separator.run([]) end)
    assert output != ""
  end

  test "separator command renders text when provided" do
    output = capture_io(fn -> Separator.run(["--text", "Section"]) end)
    assert String.contains?(output, "Section")
  end

  test "breadcrumbs command renders navigation items" do
    output = capture_io(fn -> Breadcrumbs.run(["Home", "Docs", "Guide"]) end)
    assert String.contains?(output, "Home")
    assert String.contains?(output, "Guide")
  end

  test "breadcrumbs command renders custom separator" do
    output = capture_io(fn -> Breadcrumbs.run(["Home", "Docs", "--separator", ">"]) end)
    assert String.contains?(output, ">")
  end

  defp strip_ansi(str), do: String.replace(str, ~r/\e\[[\d;]*m/, "")

  test "gradient command renders text with gradient" do
    output = capture_io(fn -> Gradient.run(["Hello"]) end)
    assert String.contains?(strip_ansi(output), "Hello")
  end

  test "gradient command renders with custom colors" do
    output = capture_io(fn -> Gradient.run(["Hello", "--from", "#00FF00", "--to", "#FF0000"]) end)
    assert String.contains?(strip_ansi(output), "Hello")
  end

  test "list command renders a list with header" do
    output = capture_io(fn -> List.run(["--header", "Items", "One", "Two"]) end)
    assert String.contains?(output, "Items")
    assert String.contains?(output, "One")
    assert String.contains?(output, "Two")
  end

  test "list command renders with color option" do
    output = capture_io(fn -> List.run(["--header", "Items", "--color", "red", "One"]) end)
    assert String.contains?(output, "Items")
  end

  test "message command renders a text message" do
    output = capture_io(fn -> Message.run(["--text", "Hello World"]) end)
    assert String.contains?(output, "Hello World")
  end

  test "message command renders a typed success message" do
    output = capture_io(fn -> Message.run_typed("success", ["Done!"]) end)
    assert String.contains?(output, "Done!")
  end

  test "message command renders multi-chunk text with paired colors" do
    output =
      capture_io(fn ->
        Message.run([
          "--text", "AAA ",
          "--color", "hex:#ff0000",
          "--text", "BBB ",
          "--color", "hex:#00ff00",
          "--text", "CCC",
          "--color", "hex:#0000ff"
        ])
      end)

    assert String.contains?(output, "AAA")
    assert String.contains?(output, "BBB")
    assert String.contains?(output, "CCC")
  end

  test "message command falls back to type default when chunk has no color" do
    output =
      capture_io(fn ->
        Message.run(["--type", "warning", "--text", "alert without color"])
      end)

    assert String.contains?(output, "alert without color")
  end

  test "message command applies bold to all chunks" do
    output =
      capture_io(fn ->
        Message.run(["--bold", "--text", "Bold A", "--text", "Bold B"])
      end)

    assert String.contains?(output, "Bold A")
    assert String.contains?(output, "Bold B")
    # ANSI bold (SGR 1) should appear at least once.
    assert String.contains?(output, "\x1b[1m") or String.contains?(output, "\x1b[1;")
  end

  test "message command respects positional fallback when no --text given" do
    output = capture_io(fn -> Message.run_typed("error", ["boom!"]) end)
    assert String.contains?(output, "boom!")
  end

  test "json command renders a JSON object" do
    output = capture_io(fn -> Json.run([~S({"key": "value"})]) end)
    assert String.contains?(output, "key")
    assert String.contains?(output, "value")
  end

  test "json command renders with custom indent" do
    output = capture_io(fn -> Json.run([~S({"a": 1, "b": 2}), "--indent", "4"]) end)
    assert String.contains?(output, "a")
  end
end
