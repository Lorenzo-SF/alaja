defmodule Alaja.CLI.NoColorTest do
  @moduledoc """
  Tests for the bridge between the CLI colour flags and
  `Alaja.Config.color_enabled?/0`.

  Priority — highest wins:

      1. `--force-color` / `--no-color`  (this module's job)
      2. `NO_COLOR` env var               (Config.overlay_env_vars/1)
      3. `:elixir, :ansi_enabled`, when explicitly set (`mix`, `elixir --color`)
      4. `Alaja.Terminal.tty?/0`

  Every test starts by wiping `:no_color` from the Application env so
  state leaks from neighbouring tests do not skew the assertion.
  """

  use ExUnit.Case, async: false

  alias Alaja.CLI.NoColor

  setup do
    original = Application.get_env(:alaja, :no_color)
    original_color = Application.get_env(:alaja, :color)
    original_loaded = Application.get_env(:alaja, :__conf_loaded__)
    original_no_color_env = System.get_env("NO_COLOR")
    Application.delete_env(:alaja, :no_color)
    Application.delete_env(:alaja, :color)
    System.delete_env("NO_COLOR")
    Application.delete_env(:alaja, :__conf_loaded__)

    on_exit(fn ->
      # Wipe both keys so neighbouring test files (cell_test, theme_switching,
      # printer_expanded) are not contaminated by what this suite does.
      # Next call to Config.color_enabled?/0 will re-load cleanly.
      Application.delete_env(:alaja, :no_color)
      Application.delete_env(:alaja, :__conf_loaded__)
      # `:color` outranks everything in color_enabled?/0, so a `:always`
      # left behind by a --force-color test would silently pin colour on
      # for the rest of the suite.
      Application.delete_env(:alaja, :color)
      # Also clear the system-level `NO_COLOR` env var: individual tests
      # in this file call `System.put_env("NO_COLOR", ...)` and the
      # shell-level value leaking out would silently flip the next
      # test that triggers `Config.load!/1` to colour-off.
      if original_no_color_env == nil,
        do: System.delete_env("NO_COLOR"),
        else: System.put_env("NO_COLOR", original_no_color_env)

      # Then restore the original values, if any.
      if original != nil, do: Application.put_env(:alaja, :no_color, original)

      if original_color != nil, do: Application.put_env(:alaja, :color, original_color)

      if original_loaded != nil,
        do: Application.put_env(:alaja, :__conf_loaded__, original_loaded)
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

    test "with --force-color sets :color to :always" do
      NoColor.sync(["--force-color", "message", "Hello"])
      assert Application.get_env(:alaja, :color) == :always
    end

    test "with --force-colour (British spelling) sets :color to :always" do
      NoColor.sync(["--force-colour"])
      assert Application.get_env(:alaja, :color) == :always
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

  describe "priority: CLI > env > explicit :ansi_enabled > tty" do
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

    test "without any signal, an explicit :ansi_enabled still decides" do
      NoColor.sync(["message", "Hello"])
      Application.put_env(:alaja, :no_color, false)

      # `mix test` sets this in test_helper.exs. When it is set, it wins,
      # which is what keeps `elixir --no-color` meaningful.
      assert Application.fetch_env(:elixir, :ansi_enabled) == {:ok, true}
      assert Alaja.Config.color_enabled?() == true
    end

    test "with nobody having set :ansi_enabled, the terminal decides" do
      NoColor.sync(["message", "Hello"])
      Application.put_env(:alaja, :no_color, false)

      original = Application.get_env(:elixir, :ansi_enabled)
      Application.delete_env(:elixir, :ansi_enabled)

      on_exit(fn -> Application.put_env(:elixir, :ansi_enabled, original) end)

      # The regression this pins: in a standalone release nothing sets
      # :ansi_enabled, and the old code asked IO.ANSI.enabled?/0, which
      # is a bare read defaulting to false — so a release printed plain
      # white text at a perfectly capable terminal.
      assert IO.ANSI.enabled?() == false
      assert Alaja.Config.color_enabled?() == Alaja.Terminal.tty?()
    end

    test "--force-color turns colour on where no other signal would" do
      NoColor.sync(["message", "Hello"])
      Application.put_env(:alaja, :no_color, false)

      original = Application.get_env(:elixir, :ansi_enabled)
      Application.delete_env(:elixir, :ansi_enabled)
      on_exit(fn -> Application.put_env(:elixir, :ansi_enabled, original) end)

      NoColor.sync(["--force-color", "message", "Hello"])
      assert Alaja.Config.color_enabled?() == true
    end
  end
end
