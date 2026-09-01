defmodule Alaja.CLI.DefinitionNewFeaturesTest do
  @moduledoc """
  Tests for the new DSL features added during the audit follow-up.

  The features are:
    * C12: compile-time type validation in `flag/3` and `argument/3`
    * C4: `flag :env` reads from an environment variable when the CLI
      flag is not passed
    * C5: `flag :conflicts_with` enforces mutual exclusion
    * C6: `flag :requires` enforces dependencies
    * C13: `flag :min` / `flag :max` enforce numeric ranges
    * C14: `flag :values` enforces allowed values

  These tests use `Code.compile_string/1` to compile small CLI
  definitions in-process and assert on the result. This avoids
  breaking the production DSL or the existing `cli_test_fixture.ex`.
  """

  use ExUnit.Case, async: true

  # Compile a self-contained CLI definition at the top level. The
  # module is named uniquely so multiple test invocations do not
  # collide.
  defp compile_cli(source) do
    Code.compile_string(source)
  end

  describe "C12 — compile-time type validation" do
    test "flag with an unknown type raises ArgumentError at compile time" do
      source = """
      defmodule Fixture_#{System.unique_integer([:positive])} do
        use Alaja.CLI.Definition, otp_app: :alaja

        command "test", "x" do
          flag :n, :invalid_type, []
        end
      end
      """

      assert_raise ArgumentError, ~r/invalid flag type: :invalid_type/, fn ->
        compile_cli(source)
      end
    end

    test "all 9 documented flag types compile without raising" do
      for type <- [:string, :integer, :float, :boolean, :atom, :path, :url, :color_list, :keep] do
        source = """
        defmodule Fixture_#{System.unique_integer([:positive])} do
          use Alaja.CLI.Definition, otp_app: :alaja

          command "test", "x" do
            flag :f, #{inspect(type)}, []
          end
        end
        """

        # Should compile without raising.
        compile_cli(source)
      end
    end

    test "all 9 documented argument types compile without raising" do
      for type <- [:string, :integer, :float, :boolean, :atom, :path, :url, :color_list, :keep] do
        source = """
        defmodule Fixture_#{System.unique_integer([:positive])} do
          use Alaja.CLI.Definition, otp_app: :alaja

          command "test", "x" do
            argument :a, #{inspect(type)}, []
          end
        end
        """

        compile_cli(source)
      end
    end
  end

  describe "DSL surface — new flag options compile without raising" do
    test "flag :env (C4)" do
      source = """
      defmodule Fixture_#{System.unique_integer([:positive])} do
        use Alaja.CLI.Definition, otp_app: :alaja

        command "test", "x" do
          flag :token, :string, env: "MY_TOKEN", default: "anon"
        end
      end
      """

      assert compile_cli(source) |> is_list()
    end

    test "flag :min / :max (C13)" do
      source = """
      defmodule Fixture_#{System.unique_integer([:positive])} do
        use Alaja.CLI.Definition, otp_app: :alaja

        command "test", "x" do
          flag :port, :integer, min: 1, max: 65535
        end
      end
      """

      assert compile_cli(source) |> is_list()
    end

    test "flag :values (C14)" do
      source = """
      defmodule Fixture_#{System.unique_integer([:positive])} do
        use Alaja.CLI.Definition, otp_app: :alaja

        command "test", "x" do
          flag :env, :string, values: ~w(staging production)
        end
      end
      """

      assert compile_cli(source) |> is_list()
    end

    test "flag :conflicts_with (C5)" do
      source = """
      defmodule Fixture_#{System.unique_integer([:positive])} do
        use Alaja.CLI.Definition, otp_app: :alaja

        command "test", "x" do
          flag :secure, :boolean, default: nil, conflicts_with: [:fast]
          flag :fast, :boolean, default: nil, conflicts_with: [:secure]
        end
      end
      """

      assert compile_cli(source) |> is_list()
    end

    test "flag :requires (C6)" do
      source = """
      defmodule Fixture_#{System.unique_integer([:positive])} do
        use Alaja.CLI.Definition, otp_app: :alaja

        command "test", "x" do
          flag :auth_required, :boolean, default: nil, requires: [:auth_token]
          flag :auth_token, :string, default: nil
        end
      end
      """

      assert compile_cli(source) |> is_list()
    end
  end
end
