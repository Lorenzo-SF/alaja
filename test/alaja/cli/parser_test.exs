defmodule Alaja.CLI.ParserTest do
  use ExUnit.Case

  alias Alaja.CLI.Parser

  describe "collect_repeated/2" do
    test "collects --flag=value forms" do
      result = Parser.collect_repeated(["--name=alice", "--name=bob"], "--name")
      assert result == ["alice", "bob"]
    end

    test "collects --flag value forms" do
      result = Parser.collect_repeated(["--name", "alice", "--name", "bob"], "--name")
      assert result == ["alice", "bob"]
    end

    test "returns empty list for no matches" do
      result = Parser.collect_repeated(["--other", "value"], "--name")
      assert result == []
    end
  end

  describe "parse_color/1" do
    test "parses hex colors" do
      assert Parser.parse_color("#FF8000") == {:ok, {255, 128, 0}}
    end

    test "parses named colors" do
      assert Parser.parse_color("red") == {:ok, {255, 0, 0}}
    end

    test "returns nil for nil input" do
      assert Parser.parse_color(nil) == nil
    end

    test "returns error for invalid colors" do
      result = Parser.parse_color("not_a_color")
      assert elem(result, 0) == :error
    end
  end

  describe "parse_color_opt/1" do
    test "returns RGB tuple for valid colors" do
      assert Parser.parse_color_opt("red") == {255, 0, 0}
    end

    test "returns nil for nil input" do
      assert Parser.parse_color_opt(nil) == nil
    end
  end

  describe "parse_color_list/1" do
    test "parses semicolon-separated colors" do
      assert Parser.parse_color_list("red;green;blue") ==
               {:ok, [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}]}
    end

    test "returns nil for nil input" do
      assert Parser.parse_color_list(nil) == nil
    end

    test "returns error for invalid colors" do
      result = Parser.parse_color_list("red;invalid")
      assert elem(result, 0) == :error
    end
  end

  describe "parse_env_pair/1" do
    test "parses KEY=VALUE when atom exists" do
      # Ensure the atom exists first (must match case)
      _ = :FOO
      assert Parser.parse_env_pair("FOO=bar") == {:FOO, "bar"}
    end

    test "returns nil for non-existing atom" do
      result = Parser.parse_env_pair("NEVER_EXISTING_KEY_12345=value")
      assert result == nil
    end

    test "returns nil for invalid format" do
      assert Parser.parse_env_pair("invalid") == nil
    end
  end

  describe "parse_align/1" do
    test "parses alignment strings" do
      assert Parser.parse_align("left") == :left
      assert Parser.parse_align("center") == :center
      assert Parser.parse_align("right") == :right
    end

    test "returns :left for unknown alignment" do
      assert Parser.parse_align("unknown") == :left
    end

    test "passes through atoms" do
      assert Parser.parse_align(:left) == :left
    end

    test "defaults to :left for nil" do
      assert Parser.parse_align(nil) == :left
    end
  end
end
