# alaja TUI spec (v3.0)

> Frozen spec for the alaja 3.0 TUI runtime. Source: `FASE-2 spec §1` + `ROADMAP.md §5`.
> Status: **immutable once alaja 3.0 is released** — breaking changes require a new major.

---

## 1. Goals and non-goals

Goals
- Bring the Elm Architecture (TEA) to Elixir on top of OTP, leveraging
  `GenServer` for the runtime and `Pote` for inline styling.
- Provide a double-buffered diff renderer that minimises terminal
  output (cursor moves, skip-N, style changes only).
- Provide a pluggable backend: `:tty` (real terminal with raw mode and
  kitty keyboard protocol) and `:test` (in-memory virtual terminal).
- Support keyboard, mouse, paste, resize, focus, and ticking.
- Add a layout engine (box-tree, flexbox-like) so apps declare their
  UI as nodes rather than absolute cells.
- Strict terminal safety: every code path restores the terminal on
  crash, signal, or `at_exit` (see `ROADMAP-alaja-tui-safety.md`).
- **Zero breaking changes** to the legacy 2.4 CLI and `Alaja.UI` API.

Non-goals (in 3.0)
- A full widget toolkit (sliders, dropdowns, autocomplete).
- GPU rendering.
- Multi-process rendering (one app, one GenServer, one renderer).
- Multi-window / split panes.
- Replacing the legacy CLI — apps choose TUI mode via `Alaja.App`.

---

## 2. The Model — TEA

```
   input                       Msg                   update/2
[terminal] ───► Input.parse ─────► App GenServer ──────────► state'
                                                      │
                                                      ├─► Cmd.run
                                                      └─► Sub.{attach,detach}
                                                                       │
                                                                       ▼
                                                              view/1 (View.Node.t)
                                                                       │
                                                                       ▼
                                                              Renderer.diff/2
                                                                       │
                                                                       ▼
                                                              Backend.write
```

The user defines an app module:

```elixir
defmodule MyApp do
  use Alaja.App

  @impl Alaja.App
  def init(_args), do: {:ok, 0}

  @impl Alaja.App
  def update(msg, n) do
    case msg do
      %Alaja.Msg.Key{key: "q"} -> {:halt, n}
      %Alaja.Msg.Key{key: "j"} -> {:ok, n + 1, [Alaja.Cmd.quit()]}
      _ -> {:ok, n}
    end
  end

  @impl Alaja.App
  def view(n) do
    Alaja.View.column([
      Alaja.View.text("Press j to quit (counter = #{n})"),
      Alaja.View.status_bar("F1=help q=quit")
    ])
  end

  @impl Alaja.App
  def subscriptions(_state) do
    [Alaja.Sub.keypress(), Alaja.Sub.tick(1000)]
  end
end

Alaja.App.start_link({MyApp, []}, backend: :test)
```

---

## 3. Public API

### 3.1 `Alaja.App`

Behaviour and supervisor entry point.

```elixir
defmodule MyApp do
  use Alaja.App

  @callback init(args :: term) :: {:ok, state}
  @callback update(msg :: Alaja.Msg.t(), state) ::
              {:ok, state} | {:ok, state, [Alaja.Cmd.t()]} | {:halt, state}
  @callback view(state) :: Alaja.View.Node.t()
  @callback subscriptions(state) :: [Alaja.Sub.t()]
end

@spec start_link({module(), args :: term}, keyword()) :: GenServer.on_start()
@spec stop(app :: pid() | atom()) :: :ok
@spec update(app, msg) :: :ok          # inject a Msg from outside
@spec state(app) :: state              # snapshot for inspection (test only)
@spec view(app) :: Alaja.View.Node.t() # last rendered view (test only)
```

The GenServer runs `init/1` on start, then loops:
1. Receives `Msg` → calls `update/2` → updates state and runs returned `Cmd`s.
2. Receives `Cmd` → executes it (may send `Msg` back via `send_msg`).
3. Each successful update triggers a render via `view/1` → backend.

`start_link/2` options:
- `:backend` — `:tty` (default) | `:test`. Test backends can be named for retrieval.
- `:name` — process name (default `__MODULE__`).
- `:tick` — initial tick interval (overrides `Sub.tick/1` if shorter).
- `:raw_mode` — boolean, default `true` for `:tty` (ignored for `:test`).

### 3.2 `Alaja.Msg`

All events the app can receive.

```elixir
@type t ::
        %Alaja.Msg.Key{key: String.t(), modifiers: [atom()], raw: binary()}
      | %Alaja.Msg.Mouse{action: atom(), button: atom(), x: pos_integer(), y: pos_integer()}
      | %Alaja.Msg.Resize{width: pos_integer(), height: pos_integer()}
      | %Alaja.Msg.Paste{content: String.t()}
      | %Alaja.Msg.Focus{id: term(), gain: boolean()}
      | %Alaja.Msg.Tick{}
      | %Alaja.Msg.Custom{name: atom(), payload: term()}
      | %Alaja.Msg.Quit{}
      | %Alaja.Msg.Error{kind: atom(), reason: term()}
```

Modifiers: `:ctrl`, `:alt`, `:shift`, `:meta`. `key` is the normalised
key name (see §7). `raw` preserves the original escape sequence bytes
for apps that need to inspect it.

### 3.3 `Alaja.Cmd`

Effects returned by `update/2` or scheduled independently.

```elixir
@type t ::
        Alaja.Cmd.none()
      | Alaja.Cmd.log(String.t())
      | Alaja.Cmd.send_msg(self(), msg :: Alaja.Msg.t())
      | Alaya.Cmd.send_msg(pid(), msg)
      | Alaja.Cmd.quit()
      | Alaja.Cmd.batch([t()])
```

`Cmd.send_msg(app, msg)` is sugar for `&GenServer.cast(app, {:msg, msg})`.

### 3.4 `Alaja.Sub`

Subscriptions attach a process to the app and feed events to it.

```elixir
Alaja.Sub.keypress()     # attach keyboard subscription
Alaja.Sub.tick(ms)       # attach ticking subscription
Alaja.Sub.resize()       # attach terminal-resize subscription
Alaja.Sub.mouse()        # attach mouse subscription
Alaja.Sub.paste()        # attach bracketed-paste subscription
Alaja.Sub.focus()        # attach focus-change subscription
Alaja.Sub.custom(mod)    # custom subscription, mod implements the Sub behaviour
```

Each sub has an `attach(app, state) :: {:ok, pid}` and `detach(app) :: :ok`.

### 3.5 `Alaja.View`

UI node tree. See `Alaja.View.Node` and friends in §6.

### 3.6 `Alaja.Backend`

Behaviour for rendering. Two built-in backends: `:tty` and `:test`.

```elixir
@callback init(opts) :: {:ok, state}
@callback render(state, frame :: Alaja.Frame.t()) :: {:ok, state}
@callback size(state) :: {pos_integer(), pos_integer()}
@callback shutdown(state) :: :ok
@callback read_event(state) :: {:ok, Alaja.Msg.t()} | {:error, term()}
```

---

## 4. The Frame

A `Frame` is an `NxM` grid of cells.

```elixir
@type t :: %Alaja.Frame{width: pos_integer(), height: pos_integer(), cells: %{optional({x, y}) => Alaja.Cell.t()}}

Alaja.Frame.new(80, 24) :: t()
Alaja.Frame.put(frame, x, y, cell) :: t()
Alaja.Frame.get(frame, x, y) :: Alaja.Cell.t() | nil
Alaja.Frame.clear(frame) :: t()
```

`Alaja.Cell` already exists in alaja — it carries a character, foreground
and background colour, and style attributes. The renderer treats the
frame as a 2D sparse map keyed by `{x, y}`.

---

## 5. Diff algorithm

```elixir
@spec Alaja.Renderer.diff(prev :: Frame.t(), next :: Frame.t()) :: {:ok, iodata()}
```

Algorithm:
1. Walk every cell in `next`. If different from `prev` (byte-for-byte
   cell comparison, including style), emit a "move to x,y, set style,
   write char" record.
2. Concatenate runs of unchanged cells in the current row as
   `\e[<n>C` (Cursor Forward) to skip them efficiently.
3. For rows not present in `prev` but present in `next` (or vice-versa),
   emit a "clear to EOL" before writing.

Output is **a stream of iodata** (no side effects). The backend
concatenates and writes it atomically.

The renderer wraps the frame write in a CSI `?2026` sync block
(begin/end sync) on the `:tty` backend so the terminal updates in
one frame to avoid tearing.

---

## 6. View / Layout

`Alaja.View` defines the node tree. Nodes are plain data; the layout
engine (`Alaja.Layout`) measures and arranges them against constraints.

```elixir
Alaja.View.column(children)   # flex column
Alaja.View.row(children)      # flex row
Alaja.View.grid(items, columns: n)
Alaja.View.text(content)
Alaja.View.box(child, border: :rounded, padding: 1)
Alaja.View.rule()
Alaja.View.status_bar(text)
Alaja.View.list(items, selected: 0, scroll: 0)
Alaja.View.tabs(items, active: 0)
Alaja.View.modal(child, on_esc: nil)
Alaja.View.form(fields)
Alaja.View.log(lines)
Alaja.View.tree(nodes, expanded: [])
Alaja.View.progress(pct, label: "")
```

Each node is `%Alaja.View.Node{tag, props, children, meta}`. The
layout engine resolves `flex`, `width`, `height`, `padding`, `align`
into absolute `{x, y, w, h}` rectangles.

---

## 7. Input

`Alaja.Input.parse(iodata)` is a stateful byte-level parser. Output is
`[Alaja.Msg.t()]` (zero or more messages per parse call).

- Kitty keyboard protocol (`CSI u`) is the primary path; legacy CSI
  sequences are still recognised as a fallback.
- Mouse: SGR encoding (`CSI < b ; x ; y M/m`).
- Paste: bracketed-paste mode (`CSI ?2004 h` enabled by `:tty`).
- Resize: SIGWINCH signal via `:os.set_signal`.

Modifier and key normalisation table:

| Sequence                | Msg                                      |
|-------------------------|------------------------------------------|
| `q`, `ESC q`            | `%Key{key: "q"}`                         |
| `Ctrl+c`                | `%Key{key: "c", modifiers: [:ctrl]}`     |
| `Up` arrow              | `%Key{key: "up"}`                        |
| `Enter`                 | `%Key{key: "enter"}`                     |
| `F1`                    | `%Key{key: "f1"}`                        |
| `\e[<0;10;20M`          | `%Mouse{action: :press, button: :left, x: 10, y: 20}` |

---

## 8. Terminal safety

The contract from `ROADMAP-alaja-tui-safety.md` (frozen):

- Layer 1: `Alaja.App.terminate/2` restores raw mode, cursor, mouse,
  bracketed paste, screen.
- Layer 2: `trap_exit` + `handle_info` cleanup if a child crashes.
- Layer 3: `Alaja.TerminalGuardian` monitors the app and restores on
  death.
- Layer 4: `System.at_exit/0` handler registered at start.
- Signals: SIGINT, SIGTERM, SIGTSTP (`:os.set_signal/2`).
- `Alaja.Terminal.RawMode` guard remembers prior state and disables on
  cleanup.

These tests are mandatory for the DoD:
1. Normal exit restores terminal.
2. Crash restores terminal.
3. 100 crashes in a row restore terminal each time.
4. `at_exit` is registered.

---

## 9. Testing strategy

`Alaja.TestBackend` (see `AL-4`) starts a virtual N×M grid. Tests
assert on:
- The last frame (`frame/1`).
- A specific row as text (`frame_text/2`).
- Visibility of a tagged node (`visible?/2`).

End-to-end tests use the counter example (`examples/counter`) and the
chat example (`examples/chat`).

---

## 10. Versioning

- `Alaja.App`, `Alaja.Msg`, `Alaja.Cmd`, `Alaja.Sub`, `Alaja.Frame`,
  `Alaja.Renderer`, `Alaja.Layout`, `Alaja.Input`, `Alaja.View`,
  `Alaja.Backend`, `Alaja.TestBackend` are the new public surface.
- The legacy CLI (`Alaja.CLI.*`, `Alaja.UI`) is unchanged.

alaja 3.0.0 ships when DoD §5 of the FASE-2 spec is satisfied.
