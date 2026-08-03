defmodule Alaja.App do
  @moduledoc """
  The Elm-Architecture-style runtime for alaja 3.0.

  A user defines an app module that implements the `Alaja.App` behaviour
  (via `use Alaja.App`). The runtime is a `GenServer` that:

    1. Calls `c:init/1` to obtain the initial state.
    2. Receives `Alaja.Msg.t/0` events, calls `c:update/2`, applies the
       new state, and runs any returned `Alaja.Cmd.t/0` list.
    3. On each successful update, calls `c:view/1` to produce a
       `View.Node.t/0` and renders it through the configured backend.
    4. Manages subscriptions via `c:subscriptions/1`.

  ## Public API

      Alaja.App.start_link({MyApp, args}, opts)
      Alaja.App.update(app, msg)         # inject a Msg from outside
      Alaja.App.stop(app)
      Alaja.App.state(app)               # snapshot for tests

  ## Options

    * `:backend` — `:tty` (default) | `:test` | module implementing
      `Alaja.Backend`.
    * `:name` — process name (default `MyApp`).
    * `:width`, `:height` — initial frame size (default: backend-reported).
    * `:raw_mode` — boolean, default true for `:tty`.
    * `:tick` — initial tick interval override.

  See `docs/tui_spec.md` for the full design.
  """

  use GenServer

  alias Alaja.{Backend, Cmd, Msg, Sub}
  alias Alaja.View.Node

  @type state :: term()
  @type view :: Node.t() | nil

  @doc """
  Called when the app starts. Returns `{:ok, state}` or `{:halt, state}`.
  """
  @callback init(args :: term()) :: {:ok, state()} | {:halt, state()}

  @doc """
  Called on each event. Returns one of:

      {:ok, new_state}                       # apply new state, no cmds
      {:ok, new_state, [Cmd.t()]}            # apply + run cmds
      {:halt, new_state}                     # stop the app
  """
  @callback update(Msg.t(), state()) ::
              {:ok, state()}
              | {:ok, state(), [Cmd.t()]}
              | {:halt, state()}

  @doc "Renders the state into a View.Node tree."
  @callback view(state()) :: Node.t()

  @doc "Returns the list of subscriptions for the current state."
  @callback subscriptions(state()) :: [Sub.t()]

  defmacro __using__(_opts) do
    quote do
      @behaviour Alaja.App

      @doc false
      def child_spec(args), do: Alaja.App.child_spec(args, unquote(Macro.escape(__CALLER__.module)))
    end
  end

  @doc """
  Starts an app. `app_or_module` can be:

    * `{module, args}` — start the given module with `args`.
    * `module` — start the given module with `[]`.

  ## Options

    See moduledoc.
  """
  @spec start_link({module(), term()} | module(), keyword()) :: GenServer.on_start()
  def start_link(app, opts \\ []) when is_atom(app) or is_tuple(app) do
    {mod, args} = normalize_app(app)
    server_name = Keyword.get(opts, :name, mod)
    backend_mod = Backend.resolve(opts)
    backend_opts = Keyword.get(opts, :backend_opts, [])

    GenServer.start_link(__MODULE__, {mod, args, backend_mod, backend_opts, opts},
      name: server_name
    )
  end

  defp normalize_app(mod) when is_atom(mod), do: {mod, []}
  defp normalize_app({mod, args}), do: {mod, args}

  @doc "Returns a child spec for use in supervision trees."
  @spec child_spec({module(), term()} | module(), keyword()) :: Supervisor.child_spec()
  def child_spec(app, opts) do
    name = Keyword.get(opts, :name, elem_or_module(app))
    %{
      id: name,
      start: {__MODULE__, :start_link, [app, opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  defp elem_or_module({mod, _}), do: mod
  defp elem_or_module(mod) when is_atom(mod), do: mod

  @doc "Injects a Msg into a running app."
  @spec update(GenServer.server(), Msg.t() | map()) :: :ok
  def update(app, msg) when is_map(msg) do
    GenServer.cast(app, {:msg, msg})
    :ok
  end

  @doc "Stops the app."
  @spec stop(GenServer.server()) :: :ok
  def stop(app) do
    GenServer.stop(app, :normal)
    :ok
  end

  @doc """
  Returns the current state. **For tests only** — the result is a
  snapshot that may be stale by the time the caller reads it.
  """
  @spec state(GenServer.server()) :: state()
  def state(app), do: GenServer.call(app, :state)

  @doc """
  Returns the last rendered View.Node tree. **For tests only.**
  """
  @spec view(GenServer.server()) :: view()
  def view(app), do: GenServer.call(app, :view)

  @doc """
  Returns the last rendered frame. **For tests only.**
  """
  @spec frame(GenServer.server()) :: Frame.t() | nil
  def frame(app), do: GenServer.call(app, :frame)

  # ── GenServer callbacks ───────────────────────────────────────────────────

  @impl GenServer
  def init({mod, args, backend_mod, backend_opts, opts}) do
    Process.flag(:trap_exit, true)

    case backend_init(backend_mod, backend_opts) do
      {:ok, backend_state} ->
        size = backend_size(backend_mod, backend_state)
        initial_state = run_init(mod, args)

        case initial_state do
          {:ok, state} ->
            Process.send_after(self(), :render, 0)
            subs = run_subs(mod, state)
            sub_pids = attach_subs(subs, self())
            render = build_render(mod, state, size, opts)

            {:ok,
             %{
               mod: mod,
               state: state,
               backend_mod: backend_mod,
               backend_state: backend_state,
               size: size,
               opts: opts,
               prev_frame: nil,
               last_view: render.view,
               last_frame: render.frame,
               sub_pids: sub_pids,
               subs: subs,
               raw_mode: Keyword.get(opts, :raw_mode, true)
             }}

          {:halt, state} ->
            # init returned halt; render once so caller can inspect, then stop
            render = build_render_with_state(mod, state, size, opts)
            {:ok,
             %{
               mod: mod,
               state: state,
               backend_mod: backend_mod,
               backend_state: backend_state,
               size: size,
               opts: opts,
               prev_frame: nil,
               last_view: render.view,
               last_frame: render.frame,
               sub_pids: [],
               subs: [],
               raw_mode: Keyword.get(opts, :raw_mode, true),
               halt_after_init: true
             }}
        end

      {:error, _reason} = err ->
        err
    end
  end

  defp backend_init(Alaja.TestBackend, opts) do
    Alaja.TestBackend.init(opts)
  end

  defp backend_init(mod, opts) do
    Backend.init(mod, opts)
  end

  defp backend_size(mod, state), do: Backend.size(mod, state)

  defp run_init(mod, args) do
    if function_exported?(mod, :init, 1) do
      mod.init(args)
    else
      {:ok, nil}
    end
  end

  defp run_subs(mod, state) do
    if function_exported?(mod, :subscriptions, 1) do
      case mod.subscriptions(state) do
        list when is_list(list) -> list
        nil -> []
        _ -> []
      end
    else
      []
    end
  end

  defp attach_subs(subs, app) do
    Enum.map(subs, fn sub ->
      case Sub.attach(sub, app) do
        {:ok, pid} -> pid
        _ -> nil
      end
    end)
  end

  defp build_render(mod, state, size, opts) do
    build_render_with_state(mod, state, size, opts)
  end

  defp build_render_with_state(mod, state, size, opts) do
    view_node = run_view(mod, state)
    frame = render_view(view_node, size, opts)
    %{view: view_node, frame: frame}
  end

  defp run_view(mod, state) do
    if function_exported?(mod, :view, 1) do
      mod.view(state)
    else
      nil
    end
  end

  defp render_view(nil, _size, _opts), do: Alaja.Frame.new(80, 24)

  defp render_view(%Node{} = node, {w, h}, _opts) do
    Alaja.Layout.render_to_frame(node, w, h)
  end

  # ── Casts / Calls ────────────────────────────────────────────────────────

  @impl GenServer
  def handle_cast({:msg, msg}, s) when is_map(msg) do
    case msg do
      %Alaja.Msg.Quit{} ->
        terminate_subs(s)
        backend_shutdown(s)
        {:stop, :normal, s}

      _ ->
        new_s = do_update(s, msg)
        {:noreply, new_s}
    end
  end

  defp do_update(s, msg) do
    case s.mod.update(msg, s.state) do
      {:ok, new_state} ->
        after_update(s, new_state, [])

      {:ok, new_state, cmds} ->
        after_update(s, new_state, cmds)

      {:halt, new_state} ->
        s2 = after_update(s, new_state, [Cmd.quit()])
        terminate_subs(s2)
        backend_shutdown(s2)
        Process.send_after(self(), :final_halt, 0)
        s2
    end
  end

  defp after_update(s, state, cmds) do
    new_view = run_view(s.mod, state)
    new_frame = render_view(new_view, s.size, s.opts)
    prev_frame = s.last_frame

    case Backend.render(s.backend_mod, s.backend_state, new_frame, prev_frame) do
      {:ok, backend_state} ->
        Enum.each(cmds, fn cmd -> Cmd.run(cmd, self()) end)
        new_subs = run_subs(s.mod, state)
        reattach_subs(s, new_subs)

        %{s |
          state: state,
          backend_state: backend_state,
          prev_frame: prev_frame,
          last_view: new_view,
          last_frame: new_frame,
          subs: new_subs
        }

      {:error, _reason} ->
        # Backend failure: keep state, log error
        new_view = run_view(s.mod, state)
        Enum.each(cmds, fn cmd -> Cmd.run(cmd, self()) end)
        %{s | state: state, last_view: new_view}
    end
  end

  defp reattach_subs(s, new_subs) do
    if same_subs?(s.subs, new_subs) do
      s.sub_pids
    else
      # detach old
      s.subs
      |> Enum.zip(s.sub_pids)
      |> Enum.each(fn {sub, pid} -> Sub.detach(sub, pid) end)

      # attach new
      Enum.map(new_subs, fn sub ->
        case Sub.attach(sub, self()) do
          {:ok, pid} -> pid
          _ -> nil
        end
      end)
    end
  end

  defp same_subs?(a, b), do: subs_signature(a) == subs_signature(b)
  defp subs_signature(subs), do: Enum.map(subs, & &1.__struct__)

  @impl GenServer
  def handle_info(:render, s) do
    new_s = after_update(s, s.state, [])
    {:noreply, new_s}
  end

  def handle_info(:final_halt, s) do
    {:stop, :normal, s}
  end

  def handle_info(_other, s), do: {:noreply, s}

  @impl GenServer
  def handle_call(:state, _from, s), do: {:reply, s.state, s}
  def handle_call(:view, _from, s), do: {:reply, s.last_view, s}
  def handle_call(:frame, _from, s), do: {:reply, s.last_frame, s}

  @impl GenServer
  def terminate(_reason, s) do
    terminate_subs(s)
    backend_shutdown(s)
    :ok
  end

  defp terminate_subs(s) do
    s.subs
    |> Enum.zip(s.sub_pids)
    |> Enum.each(fn {sub, pid} -> Sub.detach(sub, pid) end)
  end

  defp backend_shutdown(s) do
    Backend.shutdown(s.backend_mod, s.backend_state)
  rescue
    _ -> :ok
  end
end
