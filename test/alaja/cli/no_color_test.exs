defmodule Alaja.CLI.NoColorTest do
  @moduledoc """
  Tests for the bridge between the CLI flag `--no-color` and
  `Alaja.Config.color_enabled?/0`.

  Priority — highest wins:

      1. `--no-color` CLI flag  (this module's job)
      2. `NO_COLOR` env var     (Config.overlay_env_vars/1)
      3. `IO.ANSI.enabled?/0`   (default fallback)

  Every test starts by wiping `:no_color` from the Application env so
  state leaks from neighbouring tests do not skew the assertion.
  """

  use ExUnit.Case, async: false

  alias Alaja.CLI.NoColor

  setup do
    original = Application.get_env(:alaja, :no_color)
    original_loaded = Application.get_env(:alaja, :__conf_loaded__)
    Application.delete_env(:alaja, :no_color)
    System.delete_env("NO_COLOR")
    Application.delete_env(:alaja, :__conf_loaded__)

    on_exit(fn ->
      # Wipe both keys so neighbouring test files (cell_test, theme_switching,
      # printer_expanded) are not contaminated by what this suite does.
      # Next call to Config.color_enabled?/0 will re-load cleanly.
      Application.delete_env(:alaja, :no_color)
      Application.delete_env(:alaja, :__conf_loaded__)

      # Then restore the original values, if any.
      if original != nil, do: Application.put_env(:alaja, :no_color, original)
      if original_loaded != nil, do: Application.put_env(:alaja, :__conf_loaded__, original_loaded)
    end)

    :ok
  end

  describe "sync/1" do
    test "with --no-color in argv sets :no_color to true" do
      NoColor.sync(["--no-color", "message", "Hello"])
      assert Application.get_env(:alaja, :no_color) == true
    end

    test "without --no-color leaves :no_color unset" do
      Application.put_env(:alaja, :no_color, false)
      NoColor.sync(["message", "Hello"])
      assert Application.get_env(:alaja, :no_color) == false
    end

    test "is idempotent on repeated calls" do
      NoColor.sync(["--no-color"])
      NoColor.sync(["--no-color"])
      assert Application.get_env(:alaja, :no_color) == true
    end

    test "handles empty argv safely" do
      NoColor.sync([])
      assert Application.get_env(:alaja, :no_color) == nil
    end
  end

  describe "priority: CLI > env > IO.ANSI" do
    test "CLI --no-color wins when NO_COLOR is unset" do
      System.delete_env("NO_COLOR")
      NoColor.sync(["--no-color", "message", "Hello"])

      assert Alaja.Config.color_enabled?() == false
    end

    test "CLI --no-color wins when NO_COLOR is set (env loses to CLI)" do
      System.put_env("NO_COLOR", "")
      NoColor.sync(["--no-color", "message", "Hello"])

      assert Alaja.Config.color_enabled?() == false
    end

    test "NO_COLOR env var disables colour when CLI flag is absent" do
      NoColor.sync(["message", "Hello"])

      # NO_COLOR is processed by Config.overlay_env_vars/1 which
      # sets :no_color to true. We simulate that here.
      System.put_env("NO_COLOR", "1")
      Application.delete_env(:alaja, :__conf_loaded__)
      Alaja.Config.load!("/nonexistent.json", skip_env: false)

      assert Alaja.Config.color_enabled?() == false
    end

    test "without any signal, colour falls back to IO.ANSI.enabled?()" do
      NoColor.sync(["message", "Hello"])

      # Ensure neither CLI nor NO_COLOR is active.
      Application.put_env(:alaja, :no_color, false)

      expected = IO.ANSI.enabled?()
      assert Alaja.Config.color_enabled?() == expected
    end
  end
end
