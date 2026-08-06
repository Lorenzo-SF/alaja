defmodule Alaja.ConfigTest do
  use ExUnit.Case, async: false

  alias Alaja.Config

  describe "get/2" do
    test "returns default value for unknown key" do
      assert Config.get(:nonexistent_key, :fallback) == :fallback
    end
  end

  describe "set/2" do
    test "sets a value in application env" do
      Config.set(:test_key, :test_value)
      assert Config.get(:test_key) == :test_value
    end
  end

  describe "all/0" do
    test "returns keyword list" do
      result = Config.all()
      assert is_list(result)
    end
  end

  describe "config_file_path/0" do
    test "returns a string path" do
      path = Config.config_file_path()
      assert is_binary(path)
      assert String.contains?(path, ".config/alaja")
    end
  end

  describe "lookup_theme_color/1" do
    setup do
      tmp_dir =
        Path.join(System.tmp_dir!(), "alaja_config_test_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(Path.join(tmp_dir, "themes"))

      dracula_path = Path.join([tmp_dir, "themes", "dracula.json"])

      File.write!(
        dracula_path,
        Jason.encode!(%{
          "name" => "dracula",
          "description" => "Dracula",
          "colors" => %{
            "primary" => [189, 147, 249],
            "ternary" => [255, 184, 108],
            "background" => [40, 42, 54]
          }
        })
      )

      System.put_env("ALAJA_THEMES_PATH", Path.join(tmp_dir, "themes"))
      # Isolate from real ~/.config/alaja/alaja.conf
      System.put_env("ALAJA_CONFIG_PATH", Path.join(tmp_dir, "alaja.conf"))
      # Force ensure_loaded to re-read (will load from non-existent file, no-op)
      Application.delete_env(:alaja, :__conf_loaded__)
      Application.put_env(:alaja, :theme_active, "dracula")

      on_exit(fn ->
        System.delete_env("ALAJA_THEMES_PATH")
        System.delete_env("ALAJA_CONFIG_PATH")
        Application.delete_env(:alaja, :theme_active)
        Application.delete_env(:alaja, :__conf_loaded__)
        File.rm_rf!(tmp_dir)
      end)

      :ok
    end

    test "returns {:ok, rgb} for a key present in the active theme" do
      Application.put_env(:alaja, :theme_active, "dracula")
      assert {:ok, {189, 147, 249}} = Config.lookup_theme_color("theme:primary")
      assert {:ok, {255, 184, 108}} = Config.lookup_theme_color("theme:ternary")
    end

    test "returns :error for a key not in the active theme" do
      assert :error = Config.lookup_theme_color("not_a_real_key")
    end
  end

  describe "load!/1 + ALAJAX_* env vars" do
    setup do
      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "alaja_config_load_test_#{:erlang.unique_integer([:positive])}"
        )

      File.mkdir_p!(tmp_dir)
      wipe_load_state!()

      on_exit(fn ->
        wipe_load_state!()
        File.rm_rf!(tmp_dir)
      end)

      {:ok, tmp_dir: tmp_dir}
    end

    # Each test starts with a defensive wipe so that, if a concurrent test
    # in another module has set ALAJA_* env vars between our setup and the
    # body of this test, our explicit delete wins. This makes the tests
    # robust against the cross-module env-var races that async: true
    # enables by default.

    test "returns :ok for a non-existent path", %{tmp_dir: tmp_dir} do
      wipe_load_state!()
      missing = Path.join(tmp_dir, "no-such-file.json")
      assert :ok = Config.load!(missing)
    end

    test "loads JSON content into Application env", %{tmp_dir: tmp_dir} do
      wipe_load_state!()

      path = Path.join(tmp_dir, "alaja.conf")

      File.write!(
        path,
        Jason.encode!(%{"color_depth" => "xterm256", "theme_active" => "midnight"})
      )

      # skip_env: deterministic file-only behaviour regardless of any
      # BEAM-global env state leaked from concurrent tests.
      Config.load!(path, skip_env: true)

      assert Application.get_env(:alaja, :color_depth) == :xterm256
      assert Application.get_env(:alaja, :theme_active) == "midnight"
    end

    test "swallows malformed JSON silently", %{tmp_dir: tmp_dir} do
      wipe_load_state!()
      path = Path.join(tmp_dir, "broken.json")
      File.write!(path, "{not valid json")
      assert :ok = Config.load!(path)
    end

    test "ALAJAX_COLOR_DEPTH overrides on-disk value", %{tmp_dir: tmp_dir} do
      wipe_load_state!()

      path = Path.join(tmp_dir, "alaja.conf")
      File.write!(path, Jason.encode!(%{"color_depth" => "xterm256"}))

      System.put_env("ALAJAX_COLOR_DEPTH", "ansi16")
      Config.load!(path)

      assert Application.get_env(:alaja, :color_depth) == :ansi16
    end

    test "ALAJAX_THEME_ACTIVE overrides on-disk value", %{tmp_dir: tmp_dir} do
      wipe_load_state!()

      path = Path.join(tmp_dir, "alaja.conf")
      File.write!(path, Jason.encode!(%{"theme_active" => "midnight"}))

      System.put_env("ALAJAX_THEME_ACTIVE", "oceanic-next")
      Config.load!(path)

      assert Application.get_env(:alaja, :theme_active) == "oceanic-next"
    after
      System.delete_env("ALAJAX_THEME_ACTIVE")
    end

    test "empty ALAJA_* env vars are ignored", %{tmp_dir: tmp_dir} do
      wipe_load_state!()

      path = Path.join(tmp_dir, "alaja.conf")
      File.write!(path, Jason.encode!(%{"color_depth" => "truecolor"}))

      System.put_env("ALAJAX_COLOR_DEPTH", "")
      Config.load!(path)

      assert Application.get_env(:alaja, :color_depth) == :truecolor
    end

    test "env vars apply even when the on-disk file is missing", %{tmp_dir: tmp_dir} do
      wipe_load_state!()

      missing = Path.join(tmp_dir, "no-such-file.json")
      System.put_env("ALAJAX_COLOR_DEPTH", "xterm256")

      Config.load!(missing)

      assert Application.get_env(:alaja, :color_depth) == :xterm256
    end
  end

  describe "NO_COLOR convention (https://no-color.org/)" do
    setup do
      wipe_load_state!()

      on_exit(fn ->
        System.delete_env("NO_COLOR")
        Application.delete_env(:alaja, :no_color)
        Application.delete_env(:alaja, :__conf_loaded__)
      end)

      :ok
    end

    test "unset NO_COLOR keeps :no_color at default (nil/false)" do
      System.delete_env("NO_COLOR")
      Config.load!("/nonexistent.json")
      refute Config.get(:no_color, false) == true
    end

    test "NO_COLOR=\"\" is ignored (empty value)" do
      System.put_env("NO_COLOR", "")
      Config.load!("/nonexistent.json")
      refute Config.get(:no_color, false) == true
    end

    test "any non-empty NO_COLOR value disables ANSI (sets :no_color)" do
      for value <- ["1", "0", "true", "yes", "anything"] do
        System.put_env("NO_COLOR", value)
        Application.delete_env(:alaja, :no_color)
        Application.delete_env(:alaja, :__conf_loaded__)
        Config.load!("/nonexistent.json")
        assert Config.get(:no_color, false) == true, "NO_COLOR=#{inspect(value)} should set :no_color"
      end
    end

    test "color_enabled?/0 returns false when NO_COLOR is set (regardless of IO.ANSI)" do
      System.put_env("NO_COLOR", "1")
      Application.delete_env(:alaja, :no_color)
      Application.delete_env(:alaja, :__conf_loaded__)
      Config.load!("/nonexistent.json")
      assert Config.color_enabled?() == false
    end

    test "color_enabled?/0 returns false when :no_color is set even with NO_COLOR unset" do
      System.delete_env("NO_COLOR")
      Application.put_env(:alaja, :no_color, true)
      Application.delete_env(:alaja, :__conf_loaded__)
      assert Config.color_enabled?() == false
    end
  end

  # Wipe the global state load!/1 and ensure_loaded/0 touch so concurrent
  # tests cannot observe leaks.
  defp wipe_load_state! do
    for var <- ~w(ALAJAX_COLOR_DEPTH ALAJA_THEME_ACTIVE) do
      System.delete_env(var)
    end

    Application.delete_env(:alaja, :__conf_loaded__)
    Application.delete_env(:alaja, :color_depth)
    Application.delete_env(:alaja, :theme_active)
  end
end
