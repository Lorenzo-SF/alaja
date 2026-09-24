defmodule Alaja.CLI.DSLValidationTest do
  @moduledoc """
  Tests for the DSL's runtime validation gates:

    * `required: true` on a flag enforces that the flag is supplied.
    * Unknown `--xxx` flags are rejected with a clear error and
      Jaro-distance-based suggestions from the current command's
      declared flag names.

  Both behaviours invoke `dispatch_main/1`, which calls
  `exit({:shutdown, 1})` on the error path. We use
  `ExUnit.CaptureIO.capture_io/2` with `:stderr` plus a wrapper that
  traps the exit and converts it into an exception so the test can
  assert on the message.
  """

  use ExUnit.Case, async: false

  defp capture_stderr_during(fn_) do
    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      Process.flag(:trap_exit, true)

      try do
        fn_.()
        :ok
      catch
        :exit, status -> {:exited, status}
        kind, reason -> {kind, reason}
      end
    end)
  end

  defp compile_cli(label, dsl_body) do
    # Each test gets a fresh module name. The atom is built at
    # runtime via `String.to_atom/1`, but we disable the credo check
    # inline because the suffix is bounded (a positive integer from
    # `System.unique_integer/1`) — no atom-table exhaustion risk.
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    module_name = :"Fixture#{label}#{System.unique_integer([:positive])}"

    Code.compile_string("""
    defmodule #{inspect(module_name)} do
      use Alaja.CLI.Definition, otp_app: :alaja

    #{dsl_body}
    end
    """)

    module_name
  end

  describe "required: true on a flag" do
    test "missing required flag renders the missing-flags error and exits" do
      module = compile_cli("req1", """
        command "deploy", "deploy something" do
          flag :target, :string, required: true
          run({__MODULE__, :noop})
        end

        def noop(_opts), do: :ok
      """)

      stderr = capture_stderr_during(fn -> apply(module, :main, [["deploy"]]) end)

      assert stderr =~ "missing required flags"
      assert stderr =~ "--target"
    end

    test "supplied required flag dispatches to the handler" do
      module = compile_cli("req2", """
        command "deploy", "deploy something" do
          flag :target, :string, required: true
          run({__MODULE__, :capture})
        end

        def capture(opts) do
          send(self(), {:captured, opts})
          :ok
        end
      """)

      capture_stderr_during(fn ->
        apply(module, :main, [["deploy", "--target", "prod"]])
      end)

      assert_received {:captured, opts}
      assert opts.target == "prod"
    end
  end

  describe "unknown flag rejection" do
    test "typo'd flag exits with a clear error and suggestions" do
      module = compile_cli("unk1", """
        command "deploy", "deploy something" do
          flag :command, :string, required: true
          run({__MODULE__, :noop})
        end

        def noop(_opts), do: :ok
      """)

      stderr =
        capture_stderr_during(fn ->
          apply(module, :main, [["deploy", "--comand", "x"]])
        end)

      assert stderr =~ "unknown flag '--comand'"
      assert stderr =~ "Did you mean"
      assert stderr =~ "--command"
    end

    test "completely unknown flag with no close match still errors cleanly" do
      module = compile_cli("unk2", """
        command "deploy", "deploy something" do
          flag :command, :string, required: true
          run({__MODULE__, :noop})
        end

        def noop(_opts), do: :ok
      """)

      stderr =
        capture_stderr_during(fn ->
          apply(module, :main, [["deploy", "--totally-different-flag", "x"]])
        end)

      assert stderr =~ "unknown flag '--totally-different-flag'"
    end

    test "positional arguments still pass through unchanged" do
      module = compile_cli("pos", """
        command "deploy", "deploy something" do
          argument :name, :string, required: true
          run({__MODULE__, :capture})
        end

        def capture(opts) do
          send(self(), {:captured, opts})
          :ok
        end
      """)

      capture_stderr_during(fn ->
        apply(module, :main, [["deploy", "production"]])
      end)

      assert_received {:captured, opts}
      assert opts.name == "production"
    end
  end
end
