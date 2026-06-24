defmodule Alaja.ConfigTest do
  use ExUnit.Case

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
      Application.put_env(:alaja, :theme_active, "dracula")

      on_exit(fn ->
        System.delete_env("ALAJA_THEMES_PATH")
        Application.delete_env(:alaja, :theme_active)
        File.rm_rf!(tmp_dir)
      end)

      :ok
    end

    test "returns {:ok, rgb} for a key present in the active theme" do
      assert {:ok, {189, 147, 249}} = Config.lookup_theme_color("primary")
      assert {:ok, {255, 184, 108}} = Config.lookup_theme_color("ternary")
    end

    test "returns :error for a key not in the active theme" do
      assert :error = Config.lookup_theme_color("not_a_real_key")
    end
  end
end
