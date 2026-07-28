defmodule Alaja.CLI.FlagParserTest do
  use ExUnit.Case, async: true

  alias Alaja.CLI.FlagParser

  @flag %{
    name: :verbose,
    type: :boolean,
    default: false,
    short: "v",
    repeatable: false
  }

  @string_flag %{
    name: :env,
    type: :string,
    default: "dev",
    short: nil,
    repeatable: false
  }

  describe "match_flag/2" do
    test "matches --name prefix" do
      assert FlagParser.match_flag([@flag], ["--verbose"]) == @flag
    end

    test "matches --name=value syntax" do
      assert FlagParser.match_flag([@flag], ["--verbose=true"]) == @flag
    end

    test "returns nil when no match" do
      assert FlagParser.match_flag([@flag], ["--other"]) == nil
    end

    test "returns nil for empty args" do
      assert FlagParser.match_flag([@flag], []) == nil
    end

    test "returns nil for empty flag list" do
      assert FlagParser.match_flag([], ["--anything"]) == nil
    end
  end

  describe "parse/2 with boolean flag" do
    test "boolean flag without value is true" do
      assert {:ok, [{:verbose, true}], []} = FlagParser.parse([@flag], ["--verbose"])
    end

    test "boolean flag with =false is false" do
      assert {:ok, [{:verbose, false}], []} = FlagParser.parse([@flag], ["--verbose=false"])
    end

    test "boolean flag with =true is true" do
      assert {:ok, [{:verbose, true}], []} = FlagParser.parse([@flag], ["--verbose=true"])
    end
  end

  describe "parse/2 with string flag" do
    test "string flag consumes next arg" do
      assert {:ok, [{:env, "production"}], []} =
               FlagParser.parse([@string_flag], ["--env", "production"])
    end

    test "string flag with =value syntax" do
      assert {:ok, [{:env, "staging"}], []} =
               FlagParser.parse([@string_flag], ["--env=staging"])
    end

    test "non-flag args pass through as remaining" do
      assert {:ok, [], ["file.txt"]} = FlagParser.parse([@flag], ["file.txt"])
    end

    test "mix of flags and non-flags" do
      assert {:ok, [{:env, "prod"}], ["other.txt"]} =
               FlagParser.parse([@string_flag], ["--env", "prod", "other.txt"])
    end
  end
end
