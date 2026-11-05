defmodule Alaja.Output do
  @moduledoc """
  Single sink for anything Alaja writes to `stderr`.

  ## Why this exists

  `IO.puts(:stderr, ...)` resolves `:stderr` through the **node's** boot
  arguments, not through the calling process's group leader. Inside a
  `Batamanta` warm BEAM daemon that means every such write lands on the
  daemon's own stderr, which nobody is watching: the client had already
  handed the command off and is blocked on a socket, so the message is
  simply lost.

  The daemon publishes the per-request stderr sink here, and this module
  routes to it when one exists. Outside the daemon nothing is published
  and writes go to the real stderr exactly as before.

  This is the one place that decides. Scattering the check across the ~19
  modules that print to stderr would be 60-odd chances to forget one, and
  a forgotten one is a silently dropped error message.
  """

  @sink_key {__MODULE__, :stderr_sink}

  @doc """
  Writes a line to the current stderr sink.

  Falls back to the real `:stderr` when no sink is published, so this is a
  drop-in replacement for `IO.puts(:stderr, iodata)`.
  """
  @spec write_error(iodata()) :: :ok
  def write_error(data) do
    text = IO.iodata_to_binary(data)

    case sink() do
      nil -> IO.puts(:stderr, text)
      pid -> IO.puts(pid, text)
    end
  end

  @doc """
  Writes to the current stderr sink **without** a trailing newline.

  For call sites that used `IO.write(:stderr, ...)` and manage their own
  separators. Shares the sink lookup with `write_error/1`.
  """
  @spec write_raw_error(iodata()) :: :ok
  def write_raw_error(data) do
    text = IO.iodata_to_binary(data)

    case sink() do
      nil -> IO.write(:stderr, text)
      pid -> IO.write(pid, text)
    end
  end

  @doc """
  Publishes the sink that `write_error/1` should use.

  Called by the daemon once per request. Requests are served one at a
  time, so a single global slot is enough — but it MUST be cleared
  afterwards, or a later request with no sink would write into a dead
  io_server.
  """
  @spec put_sink(pid() | nil) :: :ok
  def put_sink(nil), do: :persistent_term.erase(@sink_key)
  def put_sink(pid) when is_pid(pid), do: :persistent_term.put(@sink_key, pid)

  @doc """
  The currently published sink, or `nil`.
  """
  @spec sink() :: pid() | nil
  def sink do
    :persistent_term.get(@sink_key, nil)
  end
end
