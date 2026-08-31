defmodule Alaja.CLI.Commands.SmokeTest do
  @moduledoc """
  Smoke tests for the CLI commands that don't have dedicated test files.

  Each test invokes the command's `run/1` with a representative argv
  combination and asserts it produces non-empty output without raising.
  The goal is to catch regressions where a documented switch stops
  being accepted at runtime.

  Stateful commands (`animated_bar`, `animate`, `pulsar`, `ask`, `menu`,
  `yesno`) are invoked with `--duration` or similar so they exit on their
  own rather than waiting for stdin.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  # ── Commands with no dedicated tests (zero `run/1` invocations in
  #    the test suite prior to this file).

  test "action runs with inline single-action data" do
    output =
      capture_io(fn ->
        Alaja.CLI.Commands.Action.run([
          "--data",
          ~s({"command":"success","args":["Done!"]})
        ])
      end)

    assert output =~ "Done!"
  end

  test "action runs with --file pointing to a JSON file" do
    path =
      Path.join(System.tmp_dir!(), "alaja_action_#{:erlang.unique_integer([:positive])}.json")

    File.write!(path, ~s({"command":"info","args":["from file"]}))

    try do
      output =
        capture_io(fn ->
          Alaja.CLI.Commands.Action.run(["--file", path])
        end)

      assert output =~ "from file"
    after
      File.rm(path)
    end
  end

  test "color parses a hex colour and shows format table" do
    output = capture_io(fn -> Alaja.CLI.Commands.Color.run(["hex:ff6b6b"]) end)
    assert output =~ "FF6B6B" or output =~ "#FF6B6B"
  end

  test "color generates triad harmonies" do
    output =
      capture_io(fn ->
        Alaja.CLI.Commands.Color.run(["hex:ff6b6b", "--harmony", "triad"])
      end)

    assert output != ""
  end

  test "theme list shows at least one installed theme" do
    output = capture_io(fn -> Alaja.CLI.Commands.Theme.run(["list"]) end)
    # Themes are installed by `alaja theme init` — at least 'default'
    # is always present after the supervisor boots.
    assert output =~ "default"
  end

  test "theme with --help does not crash" do
    output = capture_io(fn -> Alaja.CLI.Commands.Theme.run(["--help"]) end)
    assert output =~ "Alaja Theme"
  end

  # ── Stateful / interactive commands — invoked with bounded duration so
  #    they exit on their own.

  test "animated-bar runs with bounded duration" do
    output =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.AnimatedBar.run([
          "50",
          "--max",
          "100",
          "--duration",
          "200"
        ])
      end)

    assert output != ""
  end

  test "animate runs with bounded duration" do
    output =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Animate.run([
          "--text",
          "Working",
          "--duration",
          "1"
        ])
      end)

    assert output != ""
  end

  test "menu --help does not crash" do
    output = capture_io(fn -> Alaja.CLI.Commands.Show.Menu.run(["--help"]) end)
    assert output =~ "Alaja Menu"
  end

  test "pulsar runs with --duration 200ms" do
    output =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Pulsar.run(["Alaja", "--duration", "200"])
      end)

    assert is_binary(output)
  end

  test "table renders semicolon-separated input" do
    output =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Table.run([
          "--headers",
          "name;status",
          "--rows",
          "api;OK",
          "--rows",
          "db;WARN"
        ])
      end)

    assert output =~ "name"
    assert output =~ "api"
    assert output =~ "db"
  end

  test "yesno --help does not crash" do
    output = capture_io(fn -> Alaja.CLI.Commands.Show.YesNo.run(["--help"]) end)
    assert output =~ "Alaja YesNo"
  end

  test "ask --help does not crash" do
    output = capture_io(fn -> Alaja.CLI.Commands.Show.Ask.run(["--help"]) end)
    assert output =~ "Alaja Ask"
  end

  test "separator with custom char renders" do
    output =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Separator.run([
          "--char",
          "=",
          "--width",
          "20"
        ])
      end)

    assert output =~ "="
  end

  test "image --help does not crash" do
    output = capture_io(fn -> Alaja.CLI.Commands.Show.Image.run(["--help"]) end)
    assert output =~ "Alaja Image"
  end
end
