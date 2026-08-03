defmodule Alaja.Backend do
  @moduledoc """
  Behaviour for backends. A backend is responsible for:

    * Initialising itself (`:tty` enables raw mode + kitty keyboard;
      `:test` allocates a virtual frame).
    * Rendering a frame (writing diffs to the terminal or to the virtual
      frame).
    * Reporting terminal size.
    * Reading input events as `Alaja.Msg.t()` (only `:tty` reads from
      stdin in this phase).
    * Shutting down (restoring the terminal).

  Two built-in backends ship with alaja 3.0:

    * `Alaja.Backend.Tty` — real terminal (raw mode, signal-safe).
    * `Alaja.TestBackend` — virtual N×M grid for tests.

  ## Implementing a custom backend

      defmodule MyApp.Backend.Custom do
        @behaviour Alaja.Backend
        @impl true
        def init(opts), do: ...
        @impl true
        def render(state, frame), do: ...
        @impl true
        def size(state), do: ...
        @impl true
        def read_event(state), do: ...
        @impl true
        def shutdown(state), do: ...
      end
  """

  alias Alaja.{Frame, Msg}

  @callback init(keyword()) :: {:ok, term()} | {:error, term()}
  @callback render(term(), Frame.t()) :: {:ok, term()} | {:error, term()}
  @callback size(term()) :: {pos_integer(), pos_integer()}
  @callback read_event(term()) :: {:ok, Msg.t()} | {:error, term()}
  @callback shutdown(term()) :: :ok

  @doc "Resolves a backend from the `:backend` option."
  @spec resolve(keyword()) :: module()
  def resolve(opts) do
    case Keyword.get(opts, :backend, :tty) do
      :tty -> Alaja.Backend.Tty
      :test -> Alaja.TestBackend
      mod when is_atom(mod) -> mod
    end
  end

  @doc "Helper: calls `init/1` on the backend module."
  @spec init(module(), keyword()) :: {:ok, term()} | {:error, term()}
  def init(mod, opts), do: mod.init(opts)

  @doc "Helper: calls `render/2`."
  @spec render(module(), term(), Frame.t()) :: {:ok, term()} | {:error, term()}
  def render(mod, state, frame), do: mod.render(state, frame)

  @doc "Helper: calls `size/1`."
  @spec size(module(), term()) :: {pos_integer(), pos_integer()}
  def size(mod, state), do: mod.size(state)

  @doc "Helper: calls `read_event/1`."
  @spec read_event(module(), term()) :: {:ok, Msg.t()} | {:error, term()}
  def read_event(mod, state), do: mod.read_event(state)

  @doc "Helper: calls `shutdown/1`."
  @spec shutdown(module(), term()) :: :ok
  def shutdown(mod, state), do: mod.shutdown(state)
end
