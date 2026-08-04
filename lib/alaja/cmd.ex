defmodule Alaja.Cmd do
  @moduledoc """
  Side-effects (`Cmd`) returned by `c:Alaja.App.update/2` to be executed
  after the state update.

  Cmds are **plain data** — they do not run side effects themselves. The
  runtime evaluates them in order, in the GenServer process. This makes
  updates deterministic and testable.

  ## Built-in commands

    * `none/0` — no-op.
    * `log/1` — writes a string to stderr.
    * `send_msg/2` — sends a Msg to the given app pid.
    * `quit/0` — sends a Quit Msg.
    * `batch/1` — runs multiple cmds in order.

  ## Defining custom commands

  A Cmd can be any struct that implements `Alaja.Cmd.run/2` via the
  `Alaja.Cmd.Custom` struct. The runtime calls `Alaja.Cmd.run/2` for
  unknown structs.

      defmodule MyCmd do
        defstruct [:app, :payload]
        def run(%__MODULE__{app: app, payload: payload}, app_module) do
          GenServer.cast(app, {:msg, Alaja.Msg.custom(:my_event, payload)})
          :ok
        end
      end
  """

  alias Alaja.Cmd.{None, Log, SendMsg, Quit, Batch, Custom}

  @type t ::
          None.t()
          | Log.t()
          | SendMsg.t()
          | Quit.t()
          | Batch.t()
          | Custom.t()
          | term()

  defmodule None do
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Log do
    defstruct message: ""
    @type t :: %__MODULE__{message: String.t()}
  end

  defmodule SendMsg do
    defstruct target: nil, msg: nil
    @type t :: %__MODULE__{target: pid() | atom(), msg: Alaja.Msg.t()}
  end

  defmodule Quit do
    @moduledoc "Sends an `Alaja.Msg.Quit{}` to the app."
    defstruct app: nil
    @type t :: %__MODULE__{app: pid() | atom() | nil}
  end

  defmodule Batch do
    defstruct cmds: []
    @type t :: %__MODULE__{cmds: [t()]}
  end

  defmodule Custom do
    @moduledoc "Marker struct for custom Cmds. The runtime calls `run/2` on the struct."
    defstruct mod: nil, data: nil
    @type t :: %__MODULE__{mod: module(), data: term()}
  end

  @doc "No-op."
  @spec none() :: None.t()
  def none, do: %None{}

  @doc "Log a message to stderr (logs, not stdout, so it does not pollute the frame)."
  @spec log(String.t()) :: Log.t()
  def log(message) when is_binary(message), do: %Log{message: message}

  @doc "Send a `Msg` to the given app pid (or named process)."
  @spec send_msg(pid() | atom(), Alaja.Msg.t()) :: SendMsg.t()
  def send_msg(target, msg) when is_pid(target) or is_atom(target) do
    %SendMsg{target: target, msg: msg}
  end

  @doc "Tell the app to quit."
  @spec quit() :: Quit.t()
  def quit, do: %Quit{}

  @doc "Batch a list of commands."
  @spec batch([t()]) :: Batch.t()
  def batch([]), do: %Batch{cmds: []}
  def batch(cmds) when is_list(cmds), do: %Batch{cmds: cmds}

  @doc "Wrap a custom command module and data for runtime evaluation."
  @spec custom(module(), term()) :: Custom.t()
  def custom(mod, data) when is_atom(mod), do: %Custom{mod: mod, data: data}

  @doc """
  Executes a single Cmd. Returns `:ok` or `{:error, reason}`.
  Public so the runtime (`Alaja.App`) and users can evaluate custom Cmds.
  """
  @spec run(t(), pid()) :: :ok | {:error, term()}
  def run(%None{}, _app), do: :ok
  def run(%Log{message: msg}, _app), do: IO.puts(:stderr, msg) && :ok

  def run(%SendMsg{target: target, msg: msg}, _app)
      when (is_pid(target) or is_atom(target)) and is_map(msg) do
    Alaja.App.update(target, msg)
    :ok
  end

  def run(%Quit{}, app) when is_pid(app) or is_atom(app) do
    Alaja.App.update(app, Alaja.Msg.quit())
    :ok
  end

  def run(%Quit{}, nil), do: :ok

  def run(%Batch{cmds: cmds}, app), do: run_list(cmds, app)

  def run(%Custom{mod: mod, data: data}, app) when is_atom(mod) do
    if function_exported?(mod, :run, 2) do
      mod.run(data, app)
    else
      {:error, {:missing_run, mod}}
    end
  end

  def run(other, _app), do: {:error, {:unknown_cmd, other}}

  defp run_list([], _app), do: :ok

  defp run_list([cmd | rest], app) do
    case run(cmd, app) do
      :ok -> run_list(rest, app)
      err -> err
    end
  end
end
