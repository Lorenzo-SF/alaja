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

    test "collects quoted --flag=value forms" do
      result = Parser.collect_repeated([~s(--name="alice"), ~s(--name="bob")], "--name")
      assert result == ["alice", "bob"]
    end

    test "collects single-quoted --flag value forms" do
      result = Parser.collect_repeated(["--name", "'alice'", "--name", "'bob'"], "--name")
      assert result == ["alice", "bob"]
    end

    test "collects multi-word values until next flag" do
      result = Parser.collect_repeated(["--name", "hello", "world", "--other"], "--name")
      assert result == ["hello world"]
    end

    test "collects values across multiple args inside quotes" do
      result = Parser.collect_repeated(["--name", ~S("alice), ~S(bob")], "--name")
      assert result == ["alice bob"]
    end

    test "returns empty list when flag has no value at end" do
      result = Parser.collect_repeated(["--name"], "--name")
      assert result == []
    end
  end

  describe "parse_color/1" do
    test "parses hex colors" do
      assert Parser.parse_color("hex:#FF8000") == {:ok, {255, 128, 0}}
    end

    test "parses named colors" do
      assert Parser.parse_color("hex:ff0000") == {:ok, {255, 0, 0}}
    end

    test "returns nil for nil input" do
      assert Parser.parse_color(nil) == nil
    end

    test "returns error for invalid colors" do
      result = Parser.parse_color("not_a_color")
      assert elem(result, 0) == :error
    end

    test "parses colors with surrounding whitespace" do
      assert Parser.parse_color("  hex:#FF8000  ") == {:ok, {255, 128, 0}}
    end

    test "parses colors with surrounding double quotes" do
      assert Parser.parse_color(~s("hex:#FF8000")) == {:ok, {255, 128, 0}}
    end

    test "parses colors with surrounding single quotes" do
      assert Parser.parse_color("'hex:#FF8000'") == {:ok, {255, 128, 0}}
    end
  end

  describe "parse_color_opt/1" do
    test "returns RGB tuple for valid colors" do
      assert Parser.parse_color_opt("hex:ff0000") == {255, 0, 0}
    end

    test "returns nil for nil input" do
      assert Parser.parse_color_opt(nil) == nil
    end

    test "returns nil for invalid colors" do
      assert Parser.parse_color_opt("not_a_color") == nil
    end
  end

  describe "parse_color_list/1" do
    test "parses semicolon-separated colors" do
      assert Parser.parse_color_list("hex:ff0000|hex:00ff00|hex:0000ff") ==
               {:ok, [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}]}
    end

    test "returns nil for nil input" do
      assert Parser.parse_color_list(nil) == nil
    end

    test "returns error for invalid colors" do
      result = Parser.parse_color_list("hex:ff0000|basura")
      assert elem(result, 0) == :error
    end

    test "parses colors with extra whitespace around semicolons" do
      assert Parser.parse_color_list("hex:ff0000 | hex:00ff00 | hex:0000ff") ==
               {:ok, [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}]}
    end

    test "handles empty segments in the list" do
      assert Parser.parse_color_list("hex:ff0000||hex:0000ff") ==
               {:ok, [{255, 0, 0}, {0, 0, 255}]}
    end

    test "returns error with color-specific message" do
      result = Parser.parse_color_list("hex:ff0000|invalid1|invalid2")
      assert elem(result, 0) == :error
      assert String.contains?(elem(result, 1), "invalid1")
      assert String.contains?(elem(result, 1), "invalid2")
    end
  end

  describe "parse_env_pair/1" do
    test "parses KEY=VALUE when atom exists" do
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

    test "parses KEY=VALUE with multiple = signs" do
      _ = :EQUALS
      assert Parser.parse_env_pair("EQUALS=a=b=c") == {:EQUALS, "a=b=c"}
    end

    test "parses KEY=VALUE with empty value" do
      _ = :EMPTYVAL
      assert Parser.parse_env_pair("EMPTYVAL=") == {:EMPTYVAL, ""}
    end

    test "returns nil for empty string" do
      assert Parser.parse_env_pair("") == nil
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
