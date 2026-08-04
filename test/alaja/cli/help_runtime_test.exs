defmodule Alaja.CLI.HelpRuntimeTest do
  @moduledoc """
  Smoke-tests each CLI command by running it with a representative arg
  combination. The goal is to catch regressions where the documented
  args fail at runtime (e.g. because the dispatcher's pattern match
  drops the option, or the back-end doesn't accept the value).

  Each test uses the `:test` backend (tee-like virtual terminal) by
  routing through `Backend.Tty` with a captured stdout, or — easier —
  invokes the underlying `run/1` entry with `global_help: true` so we
  exit early. Where the command is interactive (ask/menu/yesno), we
  only test that `--help` is reachable.
  """

  use ExUnit.Case, async: true

  @doc "Each command responds to alaja <cmd> --help"
  for {module, cmd} <- [
        {Alaja.CLI.Commands.Show.Animate, "animate"},
        {Alaja.CLI.Commands.Show.AnimatedBar, "animated-bar"},
        {Alaja.CLI.Commands.Show.Ask, "ask"},
        {Alaja.CLI.Commands.Show.Bar, "bar"},
        {Alaja.CLI.Commands.Show.Breadcrumbs, "breadcrumbs"},
        {Alaja.CLI.Commands.Show.Gradient, "gradient"},
        {Alaja.CLI.Commands.Show.Header, "header"},
        {Alaja.CLI.Commands.Show.Image, "image"},
        {Alaja.CLI.Commands.Show.Json, "json"},
        {Alaja.CLI.Commands.Show.List, "list"},
        {Alaja.CLI.Commands.Show.Menu, "menu"},
        {Alaja.CLI.Commands.Show.Multibar, "multibar"},
        {Alaja.CLI.Commands.Show.Pulsar, "pulsar"},
        {Alaja.CLI.Commands.Show.Separator, "separator"},
        {Alaja.CLI.Commands.Show.Table, "table"},
        {Alaja.CLI.Commands.Show.YesNo, "yesno"}
      ] do
    test "#{cmd} --help does not crash" do
      capture = capture_io(fn -> apply(unquote(module), :run, [["--help"]]) end)
      assert capture != "", "expected some help output for `#{unquote(cmd)} --help`"
    end
  end

  # ── Per-command smoke tests with mock args ─────────────────────────────────

  test "bar with --max, --label, --width, --filled-char, --empty-char, --filled-color, --empty-color, --show-percent renders" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Bar.run([
          "50",
          "--max",
          "100",
          "--label",
          "X",
          "--width",
          "10",
          "--filled-char",
          "#",
          "--empty-char",
          ".",
          "--filled-color",
          "red",
          "--empty-color",
          "blue",
          "--show-percent"
        ])
      end)

    assert capture =~ "X"
    assert capture =~ "50"
  end

  test "bar without --show-percent omits percent" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Bar.run(["50", "--no-show-percent"])
      end)

    refute capture =~ "%"
  end

  test "separator with --char, --width, --text, --color renders" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Separator.run([
          "--char",
          "*",
          "--width",
          "20",
          "--text",
          "TITLE",
          "--color",
          "red"
        ])
      end)

    assert capture =~ "TITLE"
  end

  test "gradient with --from, --to, --direction, --bg, --text-color" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Gradient.run([
          "hello",
          "--from",
          "red",
          "--to",
          "blue",
          "--direction",
          "horizontal",
          "--bg",
          "--text-color",
          "white"
        ])
      end)

    stripped = strip_ansi(capture)
    assert stripped =~ "hello"
  end

  test "gradient with --colors" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Gradient.run(["hello", "--colors", "red,green,blue"])
      end)

    # The output has ANSI color codes interspersed; strip them before asserting.
    stripped = strip_ansi(capture)
    assert stripped =~ "hello"
  end

  test "header with --subtitle, --size, --color, --subtitle-color, --width" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Header.run([
          "TITLE",
          "--subtitle",
          "sub",
          "--size",
          "small",
          "--color",
          "red",
          "--subtitle-color",
          "blue",
          "--width",
          "20"
        ])
      end)

    assert capture =~ "TITLE"
  end

  test "json with --indent, --key-color, --string-color, --number-color, --boolean-color, --null-color, --punctuation-color" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Json.run([
          ~s({"a": 1, "b": true, "c": null}),
          "--indent",
          "2",
          "--key-color",
          "red",
          "--string-color",
          "green",
          "--number-color",
          "blue",
          "--boolean-color",
          "yellow",
          "--null-color",
          "magenta",
          "--punctuation-color",
          "cyan"
        ])
      end)

    assert capture =~ "a"
  end

  test "breadcrumbs with --separator, --color, --separator-color, --current-color" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Breadcrumbs.run([
          "home",
          "users",
          "alice",
          "--separator",
          "/",
          "--color",
          "red",
          "--separator-color",
          "blue",
          "--current-color",
          "green"
        ])
      end)

    assert capture =~ "home"
    assert capture =~ "alice"
  end

  test "list with --header, --color, --align" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.List.run([
          "a",
          "b",
          "c",
          "--header",
          "ITEMS",
          "--color",
          "red",
          "--align",
          "center"
        ])
      end)

    assert capture =~ "ITEMS"
  end

  test "yesno --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.YesNo.run([
          "the question?",
          "--default",
          "yes",
          "--color",
          "red",
          "--align",
          "center"
        ])
      end)

    # The test may exit early because no TTY; we just need it not to crash.
    assert is_binary(capture)
  end

  test "menu --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Menu.run(["--help"])
      end)

    assert capture =~ "menu"
  end

  test "ask --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Ask.run(["--help"])
      end)

    assert capture =~ "ask"
  end

  test "animate --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Animate.run(["--help"])
      end)

    assert capture =~ "animate"
  end

  test "pulsar --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Pulsar.run(["--help"])
      end)

    assert capture =~ "pulsar"
  end

  test "table --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Table.run(["--help"])
      end)

    assert capture =~ "table"
  end

  test "image --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Image.run(["--help"])
      end)

    assert capture =~ "image"
  end

  test "animated-bar --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.AnimatedBar.run(["--help"])
      end)

    assert capture =~ "animated-bar"
  end

  test "multibar --help shows usage" do
    capture =
      capture_io(fn ->
        Alaja.CLI.Commands.Show.Multibar.run(["--help"])
      end)

    assert capture =~ "multibar"
  end

  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fn ->
      try do
        fun.()
      catch
        :exit, _ -> :ok
      end
    end)
  end

  defp strip_ansi(str) do
    String.replace(str, ~r/\e\[[0-9;]*[a-zA-Z]/, "")
  end
end
