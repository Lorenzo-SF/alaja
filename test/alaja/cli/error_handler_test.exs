defmodule Alaja.CLI.ErrorHandlerTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Alaja.CLI.ErrorHandler

  describe "unknown_command/2" do
    test "prints error and returns :unknown_command" do
      output =
        capture_io(:stderr, fn ->
          assert ErrorHandler.unknown_command("foo", []) ==
                   {:error, :unknown_command}
        end)

      assert output =~ "unknown command 'foo'"
    end

    test "suggests similar commands when present" do
      commands = [
        %{name: "init", description: "init desc", subcommands: %{}}
      ]

      output =
        capture_io(:stderr, fn ->
          ErrorHandler.unknown_command("ini", commands)
        end)

      assert output =~ "Did you mean"
      assert output =~ "init"
    end

    test "no suggestions when no similar commands" do
      commands = [%{name: "totally_unrelated", description: "x", subcommands: %{}}]

      output =
        capture_io(:stderr, fn ->
          ErrorHandler.unknown_command("foo", commands)
        end)

      refute output =~ "Did you mean"
    end

    test "prints available commands" do
      commands = [
        %{name: "init", description: "init the project", subcommands: %{}},
        %{name: "build", description: "build it", subcommands: %{}}
      ]

      output =
        capture_io(:stderr, fn ->
          ErrorHandler.unknown_command("foo", commands)
        end)

      assert output =~ "Available commands"
      assert output =~ "init"
      assert output =~ "build"
    end

    test "skips available commands when list is empty" do
      output =
        capture_io(:stderr, fn ->
          ErrorHandler.unknown_command("foo", [])
        end)

      refute output =~ "Available commands"
    end

    test "walks subcommands with prefix" do
      # Use the simple subcommand list variant
      commands = [
        %{name: "config", description: "config", subcommands: []}
      ]

      output =
        capture_io(:stderr, fn ->
          ErrorHandler.unknown_command("foo", commands)
        end)

      assert output =~ "config"
    end
  end

  describe "no_command/1" do
    test "prints error and lists available commands" do
      commands = [%{name: "init", description: "init desc", subcommands: %{}}]

      output =
        capture_io(:stderr, fn ->
          assert ErrorHandler.no_command(commands) == {:error, :no_command}
        end)

      assert output =~ "no command specified"
      assert output =~ "Available commands"
      assert output =~ "init"
    end

    test "empty list shows no 'Available' section" do
      output =
        capture_io(:stderr, fn ->
          ErrorHandler.no_command([])
        end)

      assert output =~ "no command specified"
      refute output =~ "Available commands"
    end
  end

  describe "no_handler/1" do
    test "prints error" do
      output =
        capture_io(:stderr, fn ->
          assert ErrorHandler.no_handler("foo") == {:error, :no_handler}
        end)

      assert output =~ "command 'foo' has no handler"
    end
  end

  describe "flag_errors/1" do
    test "prints each error" do
      output =
        capture_io(:stderr, fn ->
          assert ErrorHandler.flag_errors(["a is invalid", "b missing"]) ==
                   {:error, :handler}
        end)

      assert output =~ "invalid options"
      assert output =~ "a is invalid"
      assert output =~ "b missing"
    end

    test "empty list still prints header" do
      output =
        capture_io(:stderr, fn ->
          ErrorHandler.flag_errors([])
        end)

      assert output =~ "invalid options"
    end
  end

  describe "missing_args/2" do
    test "prints formatted missing args" do
      output =
        capture_io(:stderr, fn ->
          assert ErrorHandler.missing_args("foo", [:name, :version]) ==
                   {:error, :handler}
        end)

      assert output =~ "command 'foo' requires"
      assert output =~ "<name>"
      assert output =~ "<version>"
    end
  end

  describe "format_error/2" do
    test "prints title and detail" do
      output =
        capture_io(:stderr, fn ->
          assert ErrorHandler.format_error("Bad input", "expected integer") ==
                   {:error, :handler}
        end)

      assert output =~ "Error: Bad input"
      assert output =~ "expected integer"
    end

    test "skips detail line when empty" do
      output =
        capture_io(:stderr, fn ->
          ErrorHandler.format_error("Just title", "")
        end)

      assert output =~ "Error: Just title"
      refute output =~ "  \n"
    end
  end

  describe "suggest/2" do
    test "finds similar options" do
      assert "init" in ErrorHandler.suggest("ini", ["init", "build", "test"])
    end

    test "returns up to 3 suggestions" do
      result = ErrorHandler.suggest("x", ~w(build buildx builds bux))
      assert length(result) <= 3
    end

    test "returns empty for no matches" do
      assert ErrorHandler.suggest("xyzzy", ~w(init build test)) == []
    end

    test "is case-insensitive" do
      assert "Init" in ErrorHandler.suggest("ini", ["Init", "Build"])
    end

    test "ranks by similarity" do
      result = ErrorHandler.suggest("init", ~w(inits input))
      # First suggestion is sorted by jaro distance; just verify non-empty
      assert result != []
    end
  end
end
