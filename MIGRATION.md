# Migrating from alaja 2.x to 3.0

Alaja 3.0 introduces the **TEA-style runtime** (Elm Architecture). The
CLI 2.x API still works (alaja is backwards compatible at the CLI
level), but new code should use `Alaja.App` for stateful interactive
TUIs.

## What's new in 3.0

| Feature | 2.x | 3.0 |
|---------|-----|-----|
| Runtime | ad-hoc GenServers, manual render loop | `Alaja.App` (TEA-style GenServer) |
| Input | ad-hoc stdin reads | `Alaja.Input.parse/1` (CSI / kitty / SS3) |
| Rendering | full-frame write | `Alaja.Renderer.diff/2` (minimal CUP + chars) |
| State | n/a | `update/2` returns `{:ok, state, [Cmd.t()]}` |
| Subscriptions | manual `Sub.attach` | declarative `subscriptions/1` |
| Components | n/a | `Alaja.Components` (list, tabs, log, progress) |
| Focus | n/a | `Alaja.FocusManager` |
| Terminal safety | none | 4 layers + `System.at_exit` |

## 2.x → 3.0 migration

### Before (2.x)

```elixir
defmodule MyApp do
  def start do
    GenServer.start_link(__MODULE__, [], name: :myapp)
  end

  def init(_) do
    {:ok, %{count: 0}}
  end

  def handle_call(:tick, _from, state) do
    state = %{state | count: state.count + 1}
    render(state)
    {:reply, :ok, state}
  end

  def render(state) do
    IO.puts("Count: #{state.count}")
  end
end
```

### After (3.0)

```elixir
defmodule MyApp do
  use Alaja.App

  alias Alaja.{Msg, View.Node, as: V}

  @impl Alaja.App
  def init(_args), do: {:ok, 0}

  @impl Alaja.App
  def update(%Msg.Key{key: "q"}, _n), do: {:halt, 0}
  def update(%Msg.Key{key: "+"}, n), do: {:ok, n + 1}
  def update(_, n), do: {:ok, n}

  @impl Alaja.App
  def view(n) do
    V.column([
      V.text("Count: #{n}"),
      V.status_bar("+/- to change, q to quit")
    ])
  end

  @impl Alaja.App
  def subscriptions(_n), do: []
end

# Start
{:ok, _} = Alaja.App.start_link({MyApp, []}, backend: :tty)
```

## Behaviour

```elixir
@callback init(args :: term()) :: {:ok, state()} | {:halt, state()}
@callback update(Msg.t(), state()) ::
            {:ok, state()}
            | {:ok, state(), [Cmd.t()]}
            | {:halt, state()}
@callback view(state()) :: Alaja.View.Node.t()
@callback subscriptions(state()) :: [Alaja.Sub.t()]
```

## Cmd union

Cmds are plain data. The runtime evaluates them in order after each
state update:

| Cmd | Purpose |
|-----|---------|
| `Cmd.none/0` | no-op |
| `Cmd.log/1` | log a string to stderr |
| `Cmd.send_msg/2` | send a Msg to another pid (or self) |
| `Cmd.quit/0` | request graceful halt |
| `Cmd.batch/1` | run multiple Cmds in sequence |
| `Cmd.custom/2` | user-defined Cmd (implements `run/2`) |

## Sub union

| Sub | Purpose |
|-----|---------|
| `Sub.keypress/0` | keyboard input |
| `Sub.tick/1` | periodic tick (ms) |
| `Sub.resize/0` | SIGWINCH resize |
| `Sub.mouse/0` | mouse input (SGR 1006) |
| `Sub.paste/0` | bracketed paste content |
| `Sub.focus/0` | focus gain/loss |
| `Sub.custom/2` | user-defined sub (implements `attach/2` + `detach/2`) |

## Backend

The `:backend` option controls how the frame is rendered:

* `:tty` (default) — real terminal with raw mode + diff rendering
* `:test` — virtual N×M grid for tests (`Alaja.TestBackend`)
* `MyApp.Backend` — implement `Alaja.Backend` behaviour

## Terminal safety (DoD)

Apps using `:tty` backend get 4 layers of safety automatically:

1. **Raw mode init/cleanup**: alt screen, cursor hide, kitty kbd query,
   bracketed paste enabled on init; reverse sequence on shutdown.
2. **Double-init guard**: `state.owns_raw_mode` flag prevents nested
   init.
3. **Panic rescue**: `App.terminate/2` wraps each cleanup step in
   `try/rescue/catch` so a single failure doesn't block the rest.
4. **at_exit hook**: `System.at_exit/1` registered via `:persistent_term`
   (idempotent) ensures terminal is restored even on BEAM crash.

No user code required.
