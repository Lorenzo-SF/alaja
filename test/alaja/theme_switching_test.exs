defmodule Alaja.ThemeSwitchingTest do
  @moduledoc """
  Regression tests for `Alaja.Theme` switching semantics.

  Bug history (pre-v0.3.5):
  - `alaja config init` wrote hardcoded themes with only 11 colour keys
    (no `debug`, `happy`, `sad`, `gradient_1..6`, etc.).
  - The JSON format used `{"rgb": [r,g,b]}` but Pote's resolver
    expected flat `[r,g,b]` arrays, so all lookups returned
    `:not_found` and fell back to Pote's hardcoded `@default_colors`.
  - As a result, `theme:<key>` and `Pote.parse(:success)` always
    returned the same colour regardless of the active theme.

  Fix (v0.3.5):
  - `alaja config init` now calls `Alaja.Theme.install_template/1`
    for every built-in Pote template, so themes are written in the
    correct flat-array format with the full 22-key set.
  - `alaja config theme set NAME` now calls `Alaja.Theme.activate/1`
    which writes through to `Application.put_env` and re-registers
    the Pote resolver — both atom and string `theme:` lookups.
  - `alaja config theme list` now uses `Alaja.Theme.list/0` as the
    single source of truth (instead of listing files in the dir).
  """

  use ExUnit.Case

  alias Alaja.{Config, Theme}

  setup do
    # Use a sandboxed themes dir so we don't trample the user's real config.
    sandbox = Path.join(System.tmp_dir!(), "alaja-theme-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(sandbox)
    System.put_env("ALAJA_THEMES_PATH", sandbox)

    # Install all built-in templates into the sandbox dir.
    Enum.each(Theme.templates(), &Theme.install_template/1)

    on_exit(fn ->
      File.rm_rf!(sandbox)
      System.delete_env("ALAJA_THEMES_PATH")
    end)

    :ok
  end

  describe "install_template/1" do
    test "writes JSON in flat [r,g,b] format" do
      assert :ok = Theme.install_template("default")
      path = Path.join(Theme.storage_dir(), "default.json")
      {:ok, content} = File.read(path)
      assert {:ok, parsed} = Jason.decode(content)

      # Pote.Theme's resolver looks up data["colors"][key] and expects
      # a 3-element list, not a map like {"rgb": [...]}.
      primary = get_in(parsed, ["colors", "primary"])

      assert is_list(primary)
      assert length(primary) == 3
      assert Enum.all?(primary, &is_integer/1)
    end

    test "every template has the full 22-key colour set" do
      for name <- Theme.templates() do
        {:ok, data} = Config.load_theme(name)
        colors = data["colors"]
        keys = Map.keys(colors) |> Enum.sort()

        for required_key <- ~w(primary secondary ternary quaternary no_color background
                                success warning error info menu alert critical debug
                                happy sad gradient_1 gradient_2 gradient_3
                                gradient_4 gradient_5 gradient_6) do
          assert required_key in keys,
                 "theme #{name} missing required key #{required_key}"
        end
      end
    end
  end

  describe "activate/1 changes the active theme" do
    test "Pote.parse(:atom) returns different RGB tuples per theme" do
      Theme.activate("default")
      {:ok, default_success} = Pote.parse(:success)

      Theme.activate("dracula")
      {:ok, dracula_success} = Pote.parse(:success)

      Theme.activate("nord")
      {:ok, nord_success} = Pote.parse(:success)

      Theme.activate("light")
      {:ok, light_success} = Pote.parse(:success)

      assert default_success != dracula_success,
             "default and dracula must differ for :success"

      assert default_success != nord_success,
             "default and nord must differ for :success"

      assert default_success != light_success,
             "default and light must differ for :success"
    end

    test "Pote.parse(\"theme:<key>\") returns different RGB tuples per theme" do
      Theme.activate("default")
      {:ok, d} = Pote.parse("theme:debug")

      Theme.activate("dracula")
      {:ok, dr} = Pote.parse("theme:debug")

      Theme.activate("light")
      {:ok, l} = Pote.parse("theme:debug")

      assert d != dr
      assert d != l
      assert dr != l
    end

    test "every colour key (debug, happy, sad, gradient_1..6) is theme-aware" do
      Theme.activate("default")
      default_colors = Enum.into(~w(debug happy sad gradient_1 gradient_2 gradient_3 gradient_4 gradient_5 gradient_6), %{}, fn k ->
        {:ok, c} = Pote.parse("theme:#{k}")
        {k, c}
      end)

      Theme.activate("dracula")
      dracula_colors = Enum.into(~w(debug happy sad gradient_1 gradient_2 gradient_3 gradient_4 gradient_5 gradient_6), %{}, fn k ->
        {:ok, c} = Pote.parse("theme:#{k}")
        {k, c}
      end)

      # At least some keys should differ between themes — otherwise the
      # resolver is falling back to a hardcoded default palette.
      differences =
        Enum.count(default_colors, fn {k, c} ->
          Map.get(dracula_colors, k) != c
        end)

      assert differences >= 5,
             "expected at least 5/9 keys to differ between default and dracula, got #{differences}"
    end

    test "Alaja.print_success uses the active theme's colour" do
      # Capture the ANSI escape from print_success and verify it changes.
      capture_color = fn ->
        out = ExUnit.CaptureIO.capture_io(fn -> Alaja.print_success("ok") end)
        [_h, r, g, b | _] = Regex.run(~r/\e\[38;2;(\d+);(\d+);(\d+)m/, out)
        {String.to_integer(r), String.to_integer(g), String.to_integer(b)}
      end

      Theme.activate("default")
      c1 = capture_color.()

      Theme.activate("dracula")
      c2 = capture_color.()

      Theme.activate("light")
      c3 = capture_color.()

      assert c1 != c2
      assert c1 != c3
      assert c2 != c3
    end

    test "Alaja.print_error uses the active theme's colour" do
      capture_color = fn ->
        out = ExUnit.CaptureIO.capture_io(fn -> Alaja.print_error("fail") end)
        [_h, r, g, b | _] = Regex.run(~r/\e\[38;2;(\d+);(\d+);(\d+)m/, out)
        {String.to_integer(r), String.to_integer(g), String.to_integer(b)}
      end

      Theme.activate("default")
      c1 = capture_color.()

      Theme.activate("dracula")
      c2 = capture_color.()

      assert c1 != c2
    end
  end

  describe "list/0 returns the installed themes" do
    test "after install_template for every built-in, list returns them all" do
      names = Theme.list() |> Enum.sort()
      expected = Theme.templates() |> Enum.sort()

      assert names == expected,
             "expected #{inspect(expected)}, got #{inspect(names)}"
    end
  end

  describe "Application.start/2 loads alaja.conf before registering resolver" do
    # Regression test for the bug where every escript started with
    # `:theme_active` unset in Application env, so `theme:<key>` lookups
    # always fell back to the default theme (ignoring whatever the user
    # had persisted via `alaja config theme set`).
    #
    # The fix: `Alaja.Application.start/2` calls
    # `Alaja.Config.ensure_loaded/0` before `Theme.register_with_pote/0`,
    # so by the time the resolver is consulted, `:theme_active` is already
    # in app env.

    test "persisted theme_active is honoured in this process" do
      # Simulate the "process restart" effect: wipe Application env
      # (just like a new escript process would start with a fresh env)
      # and write an alaja.conf with theme_active: dracula into a
      # sandbox location pointed at by ALAJA_CONFIG_PATH.
      Application.delete_env(:alaja, :theme_active)
      Application.delete_env(:alaja, :__conf_loaded__)

      sandbox_conf =
        Path.join(System.tmp_dir!(), "alaja-conf-test-#{System.unique_integer([:positive])}.conf")

      File.write!(sandbox_conf, ~s({"theme_active": "dracula"}))

      original = System.get_env("ALAJA_CONFIG_PATH")
      System.put_env("ALAJA_CONFIG_PATH", sandbox_conf)

      try do
        # Re-load from disk. This is what Application.start/2 does at boot.
        :ok = Alaja.Config.ensure_loaded()

        # Without anyone calling Alaja.Theme.activate/1, the resolver should
        # now see the persisted theme from alaja.conf.
        assert Application.get_env(:alaja, :theme_active) == "dracula",
               "Application.get_env(:alaja, :theme_active) must be \"dracula\" after Config.ensure_loaded"

        {:ok, parsed} = Pote.parse("theme:ternary")

        # dracula.ternary = {255, 184, 108} (golden value)
        assert parsed == {255, 184, 108},
               "theme:ternary must resolve to dracula's {255, 184, 108}; got: #{inspect(parsed)}"
      after
        if original, do: System.put_env("ALAJA_CONFIG_PATH", original), else: System.delete_env("ALAJA_CONFIG_PATH")
        File.rm!(sandbox_conf)
      end
    end

    test "Config.ensure_loaded/0 is callable as a public function" do
      assert function_exported?(Alaja.Config, :ensure_loaded, 0)
      assert :ok = Alaja.Config.ensure_loaded()
      assert :ok = Alaja.Config.ensure_loaded()
    end

    test "Application.start/2 source order is config-load-then-resolver-register" do
      source = File.read!("lib/alaja/application.ex")
      ensure_idx = source |> String.split("Config.ensure_loaded()") |> List.first() |> String.length()
      register_idx = source |> String.split("Theme.register_with_pote()") |> List.first() |> String.length()

      assert ensure_idx > 0,
             "Config.ensure_loaded() must be called in Alaja.Application.start/2"
      assert register_idx > 0,
             "Theme.register_with_pote() must be called in Alaja.Application.start/2"
      assert ensure_idx < register_idx,
             "Config.ensure_loaded() must be called BEFORE Theme.register_with_pote()"
    end
  end
end