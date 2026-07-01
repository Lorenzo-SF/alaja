defmodule Alaja.CLITestFixture do
  @moduledoc """
  Test-only CLI definition used to exercise Alaja.CLI.Definition from
  the test suite. Captures the opts passed to its `run/1` callbacks
  in a NamedTuple on the calling process so tests can inspect them.

  The test calls exec/1 from a Task.async task and stores the test pid
  in the process dictionary under :alaja_test_pid. The run callback
  reads that pid and sends opts back to it.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "echo", "Echo the flag values" do
    flag(:n, :integer, default: 0)
    flag(:f, :float, default: 0.0)
    flag(:p, :path, default: "")
    flag(:u, :url, default: "")
    flag(:colors, :color_list, default: [])

    run({__MODULE__, :echo})
  end

  @doc false
  def echo(opts) do
    case Process.get(:alaja_test_pid) do
      nil -> :ok
      pid -> send(pid, {:alaja_cli_capture, opts})
    end
  end
end
