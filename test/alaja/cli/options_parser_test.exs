defmodule Alaja.CLI.OptionsParserTest do
  use ExUnit.Case, async: true

  alias Alaja.CLI.OptionsParser

  describe "parse/2" do
    test "parses string options" do
      schema = %{
        switches: [color: :string],
        aliases: [],
        defaults: []
      }

      {opts, rest, errors} = OptionsParser.parse(["--color", "red"], schema)
      assert opts[:color] == "red"
      assert rest == []
      assert errors == []
    end

    test "applies defaults" do
      schema = %{
        switches: [color: :string],
        aliases: [],
        defaults: [color: "blue"]
      }

      {opts, rest, _errors} = OptionsParser.parse([], schema)
      assert opts[:color] == "blue"
      assert rest == []
    end

    test "parses integer options" do
      schema = %{
        switches: [width: :integer],
        aliases: [],
        defaults: []
      }

      {opts, rest, errors} = OptionsParser.parse(["--width", "42"], schema)
      assert opts[:width] == 42
      assert rest == []
      assert errors == []
    end

    test "parses boolean options" do
      schema = %{
        switches: [verbose: :boolean],
        aliases: [],
        defaults: []
      }

      {opts, rest, errors} = OptionsParser.parse(["--verbose"], schema)
      assert opts[:verbose] == true
      assert rest == []
      assert errors == []
    end

    test "parses aliases" do
      schema = %{
        switches: [color: :string],
        aliases: [c: :color],
        defaults: []
      }

      {opts, rest, errors} = OptionsParser.parse(["-c", "red"], schema)
      assert opts[:color] == "red"
      assert rest == []
      assert errors == []
    end

    test "handles equals syntax" do
      schema = %{
        switches: [color: :string],
        aliases: [],
        defaults: []
      }

      {opts, rest, errors} = OptionsParser.parse(["--color=red"], schema)
      assert opts[:color] == "red"
      assert rest == []
      assert errors == []
    end

    test "preserves non-option arguments" do
      schema = %{
        switches: [color: :string],
        aliases: [],
        defaults: []
      }

      {opts, rest, errors} = OptionsParser.parse(["--color", "red", "file.txt"], schema)
      assert opts[:color] == "red"
      assert rest == ["file.txt"]
      assert errors == []
    end

    test "handles multiple options" do
      schema = %{
        switches: [color: :string, width: :integer],
        aliases: [],
        defaults: []
      }

      {opts, rest, errors} = OptionsParser.parse(["--color", "red", "--width", "100"], schema)
      assert opts[:color] == "red"
      assert opts[:width] == 100
      assert rest == []
      assert errors == []
    end
  end

  describe "parse_value/2" do
    test "parses strings" do
      assert OptionsParser.parse_value("hello", :string) == "hello"
    end

    test "parses integers" do
      assert OptionsParser.parse_value("42", :integer) == 42
    end

    test "parses floats" do
      assert OptionsParser.parse_value("3.14", :float) == 3.14
    end

    test "parses booleans" do
      assert OptionsParser.parse_value("true", :boolean) == true
      assert OptionsParser.parse_value("1", :boolean) == true
      assert OptionsParser.parse_value("yes", :boolean) == true
      assert OptionsParser.parse_value("on", :boolean) == true
      assert OptionsParser.parse_value("false", :boolean) == false
    end

    test "parses atoms" do
      assert OptionsParser.parse_value("hello", :atom) == :hello
    end
  end
end
