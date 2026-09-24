defmodule Alaja.CLI.DSLValidationTest do
  @moduledoc """
  Tests for the DSL's runtime validation gates:

    * `required: true` on a flag enforces that the flag is supplied.
    * Unknown `--xxx` flags are rejected with a clear error and
      Jaro-distance-based suggestions from the current command's
      declared flag names.

  Each test compiles a self-contained `Alaja.CLI.Definition` user
  via `Code.compile_string/1` and invokes its `main/1` from a fresh
  task. `main/1` calls `exit/1` on the error path, so we trap the
  exit and convert it to a tuple we can assert on. The exit
  message is captured via the standard `Process.exit/1` channel —
  no IO buffer tricks needed because the assertion is on the
  *status*, not the rendered text.
  """

  use ExUnit.Case, async: false

  # Run `fun.()` inside a `Task` and surface the exit reason (or
  # crash) as a tuple. Returns:
  #
  #   `{:ok, result}`      — fun returned normally
  #   `{:exit, reason}`    — fun called `exit/1` with `reason`
  #   `{:crash, kind, reason}` — fun raised something else
  #   `:timeout`           — fun didn't return within 2 s
  defp run_in_task(fun) do
    parent = self()

    task =
      Task.async(fn ->
        try do
          result = fun.()
          send(parent, {:done, :ok, result})
        catch
          :exit, reason -> send(parent, {:done, {:exit, reason}, nil})
          kind, reason -> send(parent, {:done, {:crash, kind, reason}, nil})
        end
      end)

    Process.flag(:trap_exit, true)

    result =
      receive do
        {:done, status, value} -> {status, value}
        {:EXIT, ^task, reason} -> {{:exit, reason}, nil}
      after
        2_000 -> :timeout
      end

    Process.flag(:trap_exit, false)
    result
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
    test "missing required flag exits with the standard shutdown reason" do
      module = compile_cli("req1", """
        command "deploy", "deploy something" do
          flag :target, :string, required: true
          run({__MODULE__, :noop})
        end

        def noop(_opts), do: :ok
      """)

      assert {:exit, {:shutdown, 1}} =
               run_in_task(fn -> apply(module, :main, [["deploy"]]) end)
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

      assert {:ok, _} =
               run_in_task(fn ->
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
               run_in_task(fn ->
                 apply(module, :main, [["deploy", "--comand", "x"]])
               end)
    end

    test "typo'd flag error message includes the suggestion" do
      # Single test that exercises the stderr render path. CaptureIO
      # on :stderr works for non-exiting renders (the help path);
      # here we use the proven `Process.flag(:trap_exit, true)` +
      # `try/catch :exit` pattern from the codebase to capture the
      # IO output.
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
               run_in_task(fn ->
                 apply(module, :main, [["deploy", "--totally-different-flag", "x"]])
               end)
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

      assert {:ok, _} =
               run_in_task(fn ->
                 apply(module, :main, [["deploy", "production"]])
               end)

      assert_received {:captured, opts}
      assert opts.name == "production"
    end
  end
end
