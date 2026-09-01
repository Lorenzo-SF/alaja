defmodule Alaja.Sub do
  @moduledoc """
  Subscriptions attach background processes to an `Alaja.App` and feed
  events back as `Alaja.Msg.t()` values.

  A subscription is plain data describing what should be attached.
  The runtime manages the lifecycle: `attach/2` spawns a process
  (via `c:attach/2`) and `detach/1` stops it (via `c:detach/2`).

  ## Built-in subs

    * `keypress/0` — keyboard input.
    * `tick/1` — periodic tick every N ms.
    * `resize/0` — terminal resize (SIGWINCH).
    * `mouse/0` — mouse input.
    * `paste/0` — bracketed-paste content.
    * `focus/0` — focus gain/loss on the focused node.
    * `custom/1` — user-defined subscription.

  ## Custom subs

  Implement the `attach/2` and `detach/2` callbacks and pass the module
  to `custom/1`. The attached process should `cast` `{:msg, msg}` to
  the app for each event.
  """

  @type t ::
          %Alaja.Sub.Keypress{}
          | %Alaja.Sub.Tick{interval_ms: pos_integer()}
          | %Alaja.Sub.Resize{}
          | %Alaja.Sub.Mouse{}
          | %Alaja.Sub.Paste{}
          | %Alaja.Sub.Focus{}
          | %Alaja.Sub.Custom{mod: module(), opts: keyword()}

  defmodule Keypress do
    @moduledoc "Keyboard input subscription."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Tick do
    @moduledoc "Periodic tick subscription, fired every `interval_ms` milliseconds."
    defstruct interval_ms: 1000
    @type t :: %__MODULE__{interval_ms: pos_integer()}
  end

  defmodule Resize do
    @moduledoc "Terminal resize (SIGWINCH) subscription."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Mouse do
    @moduledoc "Mouse input subscription."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Paste do
    @moduledoc "Bracketed-paste content subscription."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Focus do
    @moduledoc "Focus gain/loss subscription."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Custom do
    @moduledoc "User-defined subscription backed by a module implementing `attach/2` and `detach/2`."
    defstruct mod: nil, opts: []
    @type t :: %__MODULE__{mod: module(), opts: keyword()}
  end

  @doc "Keyboard subscription."
  @spec keypress() :: Keypress.t()
  def keypress, do: %Keypress{}

  @doc "Periodic tick subscription, fired every `ms` milliseconds."
  @spec tick(pos_integer()) :: Tick.t()
  def tick(ms) when is_integer(ms) and ms > 0, do: %Tick{interval_ms: ms}

  @doc "Terminal resize subscription (SIGWINCH)."
  @spec resize() :: Resize.t()
  def resize, do: %Resize{}

  @doc "Mouse subscription."
  @spec mouse() :: Mouse.t()
  def mouse, do: %Mouse{}

  @doc "Bracketed-paste subscription."
  @spec paste() :: Paste.t()
  def paste, do: %Paste{}

  @doc "Focus subscription."
  @spec focus() :: Focus.t()
  def focus, do: %Focus{}

  @doc "Custom subscription module + opts."
  @spec custom(module(), keyword()) :: Custom.t()
  def custom(mod, opts \\ []) when is_atom(mod), do: %Custom{mod: mod, opts: opts}

  @doc """
  Attaches a subscription. Returns `{:ok, pid}` or `{:error, reason}`.
  Most built-in subs are no-ops in this minimal phase — they return
  a dummy process that immediately exits. They are wired into the
  Input parser and renderer in later tasks.
  """
  @spec attach(t(), pid()) :: {:ok, pid()} | {:error, term()}
  def attach(%Keypress{}, _app), do: {:ok, spawn(fn -> :ok end)}

  def attach(%Tick{interval_ms: ms}, app) when is_integer(ms) and ms > 0 do
    pid =
      spawn_link(fn ->
        loop_tick(app, ms)
      end)

    {:ok, pid}
  end

  def attach(%Resize{}, _app), do: {:ok, spawn(fn -> :ok end)}
  def attach(%Mouse{}, _app), do: {:ok, spawn(fn -> :ok end)}
  def attach(%Paste{}, _app), do: {:ok, spawn(fn -> :ok end)}
  def attach(%Focus{}, _app), do: {:ok, spawn(fn -> :ok end)}

  def attach(%Custom{mod: mod, opts: opts}, app) do
    if function_exported?(mod, :attach, 2) do
      mod.attach(opts, app)
    else
      {:error, {:missing_attach, mod}}
    end
  end

  @doc """
  Detaches a subscription. Idempotent.
  """
  @spec detach(t(), pid() | nil) :: :ok
  def detach(%Keypress{}, _pid), do: :ok
  def detach(%Tick{}, nil), do: :ok

  def detach(%Tick{}, pid) when is_pid(pid) do
    Process.exit(pid, :normal)
    :ok
  end

  def detach(%Resize{}, _pid), do: :ok
  def detach(%Mouse{}, _pid), do: :ok
  def detach(%Paste{}, _pid), do: :ok
  def detach(%Focus{}, _pid), do: :ok

  def detach(%Custom{mod: mod}, pid) do
    if function_exported?(mod, :detach, 2) do
      mod.detach(pid, nil)
      :ok
    else
      :ok
    end
  end

  defp loop_tick(app, ms) do
    Process.sleep(ms)
    Alaja.App.update(app, Alaja.Msg.tick())
    loop_tick(app, ms)
  end
end
