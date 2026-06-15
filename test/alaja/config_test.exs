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
end
