defmodule Alaja.CLI.DSLValidationTest do
  @moduledoc """
  Tests for the DSL's runtime validation gates:

    * `required: true` on a flag enforces that the flag is supplied.
    * Unknown `--xxx` flags are rejected with a clear error and
      Jaro-distance-based suggestions from the current command's
      declared flag names.

  Both behaviours invoke `main/1`, which calls `exit/1` on the
  error path. We drive each invocation in a separate `Task` so the
  exit doesn't bring down the test process, and surface the exit
  reason via the trap_exit channel — no IO buffer tricks needed
  because the assertion is on the *status*, not the rendered text.

  To assert on the captured opts flowing into the handler, the test
  stashes its own pid in the process dictionary and the fixture's
  `capture/1` callback reads it via `Process.get/1` and sends to it.
  Same pattern as `test/alaja/cli/definition_test.exs`.
  """

  use ExUnit.Case, async: false

  # Run `fun.()` inside a `Task` and surface the exit reason (or
  # crash) as a tuple. Returns:
  #
  #   `{:ok, result}`      — fun returned normally
  #   `{:exit, reason}`    — fun called `exit/1` with `reason`
  #   `{:crash, kind, reason}` — fun raised something else
  #   `:timeout`           — fun didn't return within 2 s
  defp run_in_task(test_pid, fun) do
    parent = test_pid

    task =
      Task.async(fn ->
        try do
          Process.put(:alaja_test_pid, parent)
          result = fun.()
          send(test_pid, {:done, :ok, result})
        catch
          :exit, reason -> send(test_pid, {:done, {:exit, reason}, nil})
          kind, reason -> send(test_pid, {:done, {:crash, kind, reason}, nil})
        end
      end)

    Process.flag(:trap_exit, true)

    result =
      receive do
        {:done, status, value} -> {status, value}
        {:EXIT, ^task, reason} -> {:exit, reason}
      after
        2_000 -> :timeout
      end

    Process.flag(:trap_exit, false)
    result
  end

  # Compile an `Alaja.CLI.Definition` user in-process via
  # `Code.eval_string/3`.
  defp compile_cli(label, dsl_body) do
    # Each test gets a fresh module name. The atom is built at
    # runtime via `String.to_atom/1`, but we disable the credo check
    # inline because the suffix is bounded (a positive integer from
    # `System.unique_integer/1`) — no atom-table exhaustion risk.
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    module_name = :"Fixture#{label}#{System.unique_integer([:positive])}"

    source = """
    defmodule #{inspect(module_name)} do
      use Alaja.CLI.Definition, otp_app: :alaja

    #{dsl_body}
    end
    """

    Code.eval_string(source)
    module_name
  end

  describe "required: true on a flag" do
    test "missing required flag exits with the standard shutdown reason" do
      module = compile_cli("req1", """
        command "deploy", "deploy something" do
          flag :target, :string, required: true
          run({__MODULE__, :noop})
        end

        def noop(_opts), do: :ok
      """)

      assert {:exit, {:shutdown, 1}} =
               run_in_task(self(), fn -> apply(module, :main, [["deploy"]]) end)
    end

    test "supplied required flag dispatches to the handler" do
      capture_callback = """
        def capture(opts) do
          case Process.get(:alaja_test_pid) do
            nil -> :ok
            pid -> send(pid, {:captured, opts})
          end
          :ok
        end
      """

      module = compile_cli("req2", """
        command "deploy", "deploy something" do
          flag :target, :string, required: true
          run({__MODULE__, :capture})
        end

        #{capture_callback}
      """)

      assert {:ok, _} =
               run_in_task(self(), fn ->
                 apply(module, :main, [["deploy", "--target", "prod"]])
               end)

      assert_received {:captured, opts}
      assert opts.target == "prod"
    end
  end

  describe "unknown flag rejection" do
    test "typo'd flag exits with the standard shutdown reason" do
      module = compile_cli("unk1", """
        command "deploy", "deploy something" do
          flag :command, :string, required: true
          run({__MODULE__, :noop})
        end

        def noop(_opts), do: :ok
      """)

      assert {:exit, {:shutdown, 1}} =
               run_in_task(self(), fn ->
                 apply(module, :main, [["deploy", "--comand", "x"]])
               end)
    end

    test "typo'd flag error message includes the suggestion" do
      module = compile_cli("unk1msg", """
        command "deploy", "deploy something" do
          flag :command, :string, required: true
          run({__MODULE__, :noop})
        end

        def noop(_opts), do: :ok
      """)

      stderr =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Process.flag(:trap_exit, true)

          try do
            apply(module, :main, [["deploy", "--comand", "x"]])
          catch
            :exit, _ -> :caught
          end
        end)

      assert stderr =~ "unknown flag '--comand'"
      assert stderr =~ "Did you mean"
      assert stderr =~ "--command"
    end

    test "completely unknown flag still exits cleanly" do
      module = compile_cli("unk2", """
        command "deploy", "deploy something" do
          flag :command, :string, required: true
          run({__MODULE__, :noop})
        end

        def noop(_opts), do: :ok
      """)

      assert {:exit, {:shutdown, 1}} =
               run_in_task(self(), fn ->
                 apply(module, :main, [["deploy", "--totally-different-flag", "x"]])
               end)
    end

    test "positional arguments still pass through unchanged" do
      capture_callback = """
        def capture(opts) do
          case Process.get(:alaja_test_pid) do
            nil -> :ok
            pid -> send(pid, {:captured, opts})
          end
          :ok
        end
      """

      module = compile_cli("pos", """
        command "deploy", "deploy something" do
          argument :name, :string, required: true
          run({__MODULE__, :capture})
        end

        #{capture_callback}
      """)

      assert {:ok, _} =
               run_in_task(self(), fn ->
                 apply(module, :main, [["deploy", "production"]])
               end)

      assert_received {:captured, opts}
      assert opts.name == "production"
    end
  end
end
