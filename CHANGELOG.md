# Changelog

## 3.0.0 (2026-08-03)

The **3.0** release introduces a TEA-style runtime (`Alaja.App`),
stateful components, focus management, terminal safety, and a
renderer that emits minimal diffs. The 2.x CLI is still supported.

### Added

* **`Alaja.App`** — the Elm-Architecture-style runtime. A
  `GenServer` that calls `init/1`, receives `Msg.t()` events via
  `update/2`, applies new state, runs any returned `Cmd.t()` list,
  re-renders via `view/1`, and manages subscriptions. The
  `use Alaja.App` macro defines `child_spec/1` for supervision trees.

* **`Alaja.Cmd`** — union of plain-data side effects returned by
  `update/2`: `none/0`, `log/1`, `send_msg/2`, `quit/0`, `batch/1`,
  `custom/2`. The runtime evaluates them in order after each
  state update.

* **`Alaja.Sub`** — declarative subscription descriptors:
  `keypress/0`, `tick/1`, `resize/0`, `mouse/0`, `paste/0`,
  `focus/0`, `custom/2`. The runtime attaches the process on
  `init` and re-evaluates `subscriptions/1` on each update.

* **`Alaja.Msg`** — event union: `Key`, `Mouse`, `Resize`, `Paste`,
  `Focus`, `Tick`, `Custom`, `Quit`, `Error`. Built with helpers
  `key/2`, `mouse/4`, `tick/1`, `resize/2`, `paste/1`, etc.

* **`Alaja.Input`** — pure parser for raw terminal bytes → `Msg.t()`.
  Supports ASCII printable, control chars, arrow keys (CSI A/B/C/D),
  function keys (F1-F12), nav keys (Home, End, PageUp, PageDown,
  Insert, Delete), SS3 sequences, Alt-? (ESC + char), kitty keyboard
  protocol (CSI N u with modifiers), Shift+Tab (CSI 1;2 Z), and
  resize (CSI 8 ; rows ; cols t).

* **`Alaja.Backend.Tty`** — real-terminal backend. Enables alt
  screen, hides cursor, queries kitty keyboard protocol, enables
  bracketed paste on init; reverses on shutdown. Uses
  `Alaja.Renderer.diff/2` for minimal diff rendering. Safe against
  double-init (idempotent), panic (try/rescue), and BEAM crash
  (System.at_exit hook).

* **`Alaja.TestBackend`** — virtual N×M grid for tests. Stores
  frames in a queue; helpers `frame/1`, `frame_text/2`,
  `frame_string/1`, `send_msg/2`, `all_frames/1`.

* **`Alaja.Renderer.diff/2`** — computes the minimal escape
  sequence to take a terminal from `prev_frame` to `next_frame`.
  Walks both frames row by row, finds runs of consecutive changed
  cells, emits a single CSI CUP `ESC[row;colH` per run followed by
  the characters. A final `ESC[0m` reset is always appended.

* **`Alaja.Layout`** — flexbox-style layout engine. Supports
  `:text`, `:column`, `:row`, `:box` (border + padding), `:rule`,
  `:status_bar` (anchored to bottom row of the root frame), `:grid`.
  Flex distributes free space proportionally. Gap, padding,
  alignment, and box-border all supported.

* **`Alaja.Frame`** — N×M terminal frame backed by `Alaja.Buffer`.
  Facade over `Buffer` adding `put_text/4` (right-padded),
  `row_text/2` (trimmed), and `cells/1` (raw map).

* **`Alaja.View.Node`** — node tree. Builders: `text/2`, `column/2`,
  `row/2`, `box/2`, `rule/1`, `status_bar/2`, `grid/2`. Props:
  `:flex`, `:width`, `:height`, `:align`, `:padding`, `:gap`,
  `:border`, `:wrap`, `:style`, `:content`, `:columns`. Metadata
  via `meta/2`, `put_meta/3`.

* **`Alaja.Components`** — stateful UI components:
    * `ListState` (scrollable, focused selection with `>` marker)
    * `TabsState` (left/right rotation with `[ name ]` highlight)
    * `LogState` (append-only with `max_lines` rotation)
    * `ProgressState` (bar + percent)

* **`Alaja.FocusManager`** — id-based focus stack with `next/1`,
  `prev/1`, `focus/2`, `focused/1`, `focused?/2`.

* **`Alaja.Text.width/1`** — visible cell-width of a string with
  CJK and combining-mark awareness.

* **`Alaja.Config`** — extended to honor the `NO_COLOR` environment
  variable (https://no-color.org/).

* **Examples** under `examples/`:
    * `counter.exs` — minimal state transition
    * `list_scroll.exs` — `ListState` with up/down
    * `tabs.exs` — `TabsState` with left/right
    * `dashboard.exs` — three `ProgressState` + `Sub.tick/1`
    * `demo.exs` — combined: focus + tabs + list + log + progress

* **Migration guide** (`MIGRATION.md`) — 2.x → 3.0 cookbook with
  side-by-side examples.

* **Benchmarks** (`bench/bench.exs`) — layout, renderer, input
  parse, text width.

* **CHANGELOG.md** — this file.

### Changed

* `Alaja.Backend` behaviour now requires `render/3` (with
  `prev_frame` as third argument) instead of `render/2`. Backends
  that only support full-frame writes can ignore the new argument
  (the default implementation discards it).

* `Alaja.App.update/2` returns `{:ok, state, [Cmd.t()]}` (with
  optional Cmd list). Apps that don't need Cmds can keep using
  the 2-tuple form; the runtime accepts both.

* `Alaja.Layout.measure/2` and `render_to_frame/3` are the
  public entry points. The internal `do_arrange/7` is private.

### Fixed

* `Layout.measure` for `:grid` no longer uses an invalid
  `Enum.chunk_every/4` call (was passing a list as `step`).
* `Layout.do_arrange` for `:status_bar` now anchors to the root
  frame's bottom row, not the local placement's bottom.
* `Layout.draw_box` no longer drops the border when rendering a
  child; child frames are now overlaid onto the parent frame at
  the correct inner offset.
* `Buffer.put` with a string and no fg/bg no longer leaks any
  pre-existing style from a previous write.
* `Cmd.run(%SendMsg{...})` now correctly targets the GenServer
  via `Alaja.App.update/2` (was hitting `GenServer.cast` directly
  on the test process and wrapping the message in `:$gen_cast`).

### Backwards compatibility

* The 2.x CLI is unchanged. Existing `mix alaja.*` commands still
  work.
* `Alaja.Backend` implementations that only define `render/2` will
  fail to compile against the new behaviour. To migrate, add
  `render/3` with `_prev_frame` as the third argument and ignore
  it. The `Alaja.Backend.render/4` helper calls `mod.render/3`.

### Known issues

* Mouse events (CSI M) are parsed by the input parser but the
  Tty backend doesn't enable mouse tracking by default. Set
  `Application.put_env(:alaja, :mouse, true)` and the backend
  will emit the enable sequence.
* Bracketed paste content is delivered as a single string; the
  Tty backend doesn't yet split by lines or call the parser on
  each line.
