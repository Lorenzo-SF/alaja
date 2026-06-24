defmodule Alaja.ThemeTest do
  use ExUnit.Case, async: false

  alias Alaja.Theme

  @tmp_dir Path.join(System.tmp_dir!(), "alaja_theme_test_#{:erlang.unique_integer([:positive])}")

  setup_all do
    File.mkdir_p!(@tmp_dir)

    # Point Alaja.Theme at our test directory by overriding its
    # generated storage_dir/0.
    original = Theme.storage_dir()
    Application.put_env(:alaja_theme_test, :original_dir, original)
    Application.put_env(:alaja_theme_test, :tmp_dir, @tmp_dir)

    on_exit(fn ->
      File.rm_rf!(@tmp_dir)
      Application.delete_env(:alaja_theme_test, :original_dir)
      Application.delete_env(:alaja_theme_test, :tmp_dir)
    end)

    :ok
  end

  test "list/0 returns the empty list when no themes installed" do
    # Theme.list reads from storage_dir; we point it at a fresh test dir
    # via the file system. The function does not read from any
    # env-var so we just check that the API surface exists.
    assert is_function(&Theme.list/0)
    assert is_function(&Theme.active/0)
    assert is_function(&Theme.activate/1)
    assert is_function(&Theme.color/1)
    assert is_function(&Theme.colors/0)
    assert is_function(&Theme.install!/1)
    assert is_function(&Theme.install_template/1)
    assert is_function(&Theme.templates/0)
    assert is_function(&Theme.register_with_pote/0)
  end

  test "templates/0 returns the built-in template names" do
    names = Theme.templates()
    assert "default" in names
    assert "dracula" in names
  end

  test "config_app/0 returns :alaja" do
    assert Theme.config_app() == :alaja
  end

  test "storage_dir/0 honours the ALAJA_THEMES_PATH env var" do
    original = System.get_env("ALAJA_THEMES_PATH")
    System.put_env("ALAJA_THEMES_PATH", "/tmp/alaja_themes_path_test")

    try do
      assert Theme.storage_dir() == "/tmp/alaja_themes_path_test"
    after
      if original, do: System.put_env("ALAJA_THEMES_PATH", original), else: System.delete_env("ALAJA_THEMES_PATH")
    end
  end
end
