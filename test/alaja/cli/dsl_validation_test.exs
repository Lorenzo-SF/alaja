defmodule Alaja.CLI.DSLValidationTest do
  @moduledoc """
  Tests for the DSL's runtime validation gates:

    * `required: true` on a flag enforces that the flag is supplied.
    * Unknown `--xxx` flags are rejected with a clear error and
      Jaro-distance-based suggestions from the current command's
      declared flag names.

  Both behaviours invoke `main/1`, which calls `exit/1` on the
  error path. We drive each invocation in a separate `Task` so the
  exit doesn't bring down the test process, and capture the
  `stderr` written by that subprocess via a dedicated group leader
  process.

  The capture trick uses a small helper (`capture_in_subprocess/2`)
  that spawns a worker process whose `Process.group_leader/0` is a
  fresh `StringIO` device. After the worker exits (normally or via
  `exit/1`), we read everything the device accumulated.
  """

  use ExUnit.Case, async: false

  # Run `fun.()` in a child process whose group leader is a fresh
  # `StringIO`. Returns `{status, captured_stderr}` where `status`
  # is `:ok`, `{:exited, reason}`, or `{:crashed, kind, reason}`.
  defp capture_in_subprocess(fun) do
    {:ok, dev} = StringIO.open("")
    parent = self()
    ref = make_ref()

    pid =
      spawn_link(fn ->
        Process.group_leader(self(), dev)

        status =
          try do
            fun.()
            :ok
          catch
            :exit, reason -> {:exited, reason}
            kind, reason -> {:crashed, kind, reason}
          end

        send(parent, {ref, :done, status})
      end)

    Process.flag(:trap_exit, true)

    status =
      receive do
        {^ref, :done, s} -> s
        {:EXIT, ^pid, reason} -> {:exited, reason}
      after
        3_000 -> :timeout
      end

    Process.flag(:trap_exit, false)
    stderr = IO.binread(dev, :all) |> case do
      {:error, _} -> ""
      {:eof, _} -> ""
      {:ok, data} -> data
    end

    {status, stderr}
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

      {status, stderr} =
        capture_in_subprocess(fn -> apply(module, :main, [["deploy"]]) end)

      assert {:exited, _} = status
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

      {status, _stderr} =
        capture_in_subprocess(fn ->
          apply(module, :main, [["deploy", "--target", "prod"]])
        end)

      assert status == :ok
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

      {status, stderr} =
        capture_in_subprocess(fn ->
          apply(module, :main, [["deploy", "--comand", "x"]])
        end)

      assert {:exited, _} = status
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

      {status, stderr} =
        capture_in_subprocess(fn ->
          apply(module, :main, [["deploy", "--totally-different-flag", "x"]])
        end)

      assert {:exited, _} = status
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

      {status, _stderr} =
        capture_in_subprocess(fn ->
          apply(module, :main, [["deploy", "production"]])
        end)

      assert status == :ok
      assert_received {:captured, opts}
      assert opts.name == "production"
    end
  end
end
