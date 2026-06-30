# Alaja Rework Plan — Buffer-First + Audit Complete

## Goal

Make alaja **stable, robust, performant, and CV-grade**. Apply every
bug found in the audit + refactor to Buffer-First architecture +
add sacred smoke tests + optimize batch performance.

## Branch

`rework/audit-fixes-and-buffer-refactor`

## Layer-by-Layer Audit Findings

### 1. Components (`lib/alaja/components/`)

**Already return Buffer.t()**: Bar, Box, Header, Json, Separator
**Need fix** (return iodata, not Buffer):
- `AnimatedBar.render_frame/4` → `iodata()` (BUG)
- `Pulsar.render_frame/3` → `iodata()` (BUG)
- `Table.render/2` → `iodata()` (BUG, even though `render_buffer/2` already exists)
**Need canonical wrapper** (currently prints directly or no wrapper):
- `Components.Message` (does not exist; Show.Message flattens to ANSI string)
- `Components.ColorWheel.render/1` (prints directly, returns `:ok` or `iodata`)

### 2. Action (`lib/alaja/cli/commands/action.ex`)

**Critical bugs**:
1. **PERFORMANCE**: Each batch element calls `Alaja.CLI.main/1` which boots
   the entire VM (`Application.ensure_all_started(:alaja)`). For 10 actions,
   that's 10 boots. ~2-5s overhead per batch.
2. **PERFORMANCE**: `exit/1` on error kills entire process.
3. **BUG**: Implicit stdin read hangs in TTY (no `IO.respond?` check).
4. **BUG**: `build_args` splits on space, breaking args with spaces.
5. **BUG**: Recursion guard is case-sensitive.
6. **FALTA**: `--parallel N` for parallel execution.
7. **FALTA**: `--dry-run` mode.
8. **FALTA**: `--stop-on-error` option.

### 3. Options Parser (`lib/alaja/cli/options_parser.ex`)

**Bugs**:
1. `parse_integer("abc")` returns "abc" silently (no error).
2. `parse_float("abc")` same.
3. `parse_boolean` only accepts true-like values; "false", "0", "no", "off" → false (OK actually).
4. `--debug=` (with =, no value) → empty string parse, no error.
5. **FALTA**: `cast_flag_value/2` with `:path`, `:url`, `:color_list` handlers.

### 4. Syntax (`lib/alaja/syntax.ex`)

**Bugs**:
1. `highlight_ansi/2` returns `IO.iodata()` (should be Buffer.t()).
2. `highlight_content/2` returns `[{String.t(), String.t()}]` (raw tuples).
3. **FALTA**: A canonical `highlight_buffer/2` that returns Buffer.

### 5. Config (`lib/alaja/config.ex`)

**Generally OK**. Concerns:
- `safe_atom/1` only allows 2 atoms — extensibility issue.
- No env var support (`ALAJAX_*`).
- No validation of loaded theme.

### 6. Printer (`lib/alaja/printer.ex`, `basics.ex`, `interactive.ex`)

**Need audit** (pending).

### 7. Structures (`lib/alaja/structures/*.ex`)

**Need audit** (pending).

### 8. DSL (`lib/alaja/cli/definition.ex`, `parser.ex`, etc.)

**Need audit** (pending).

### 9. Cell/Buffer Engine (`lib/alaja/cell.ex`, `buffer.ex`)

**Need audit** (pending).

### 10. Bug Reports from User

1. **Bug 1 — Box width with ANSI**: `alaja message --chunk ... --align center --box` produces wide box because `wrap_with_box` flattens to ANSI string. **Root cause**: missing `Components.Message` wrapper.
2. **Bug 2 — Animated-bar kitt**: Frames overlap with previous, shell prompt mixed in. **Root cause**: `\e[NA\e[K` only clears current line.
3. **Bug 3 — Image ASCII art**: Output is empty. **Root cause**: `resize_pixels` returns numbers, `render_pixel/5` expects `{r, g, b}` tuples.
4. **Bug 4** (unconfirmed) — `alaja gradient --from "#FF6B6B"` fails. **Root cause**: `parse_color_opt` may not handle "#hex" with quotes from shell.
5. **Bug 5** (unconfirmed) — `alaja color --colors` fails with `String.downcase/2`. **Root cause**: ?
6. **Bug 6 — Performance**: Many `alaja` calls in batch are slow.

## Implementation Order (commits)

Each commit must include a test that catches the regression.

### Phase 1: Sacred Smoke Tests (red de seguridad)

1. **Commit 1**: Setup `test/alaja/cli/smoke/` framework with base infrastructure
   - `Smoke.Case` (subprocess runner, ANSI stripper, snapshot matcher)
   - `Smoke.Snapshot` (load/save/compare)
   - `mix alaja.snapshot` task (only updates snapshots with `--confirm`)

2. **Commit 2**: Smoke tests for 3 user-reported bugs:
   - `smoke/message_box_test.exs` (Bug 1)
   - `smoke/animated_bar_kitt_test.exs` (Bug 2)
   - `smoke/image_ascii_test.exs` (Bug 3)
   - All start RED (confirming the bugs exist)

3. **Commit 3**: Smoke tests for component return types:
   - `smoke/components_return_buffer_test.exs` — asserts every component.render/2 returns Buffer.t()

### Phase 2: Component Buffer Refactor

4. **Commit 4**: `Components.Table.render/2` → reuse `render_buffer/2`, return Buffer.t()
5. **Commit 5**: `Components.AnimatedBar.render/2` → wraps `render_frame`, returns Buffer
6. **Commit 6**: `Components.Pulsar.render/2` → wraps `render_frame`, returns Buffer
7. **Commit 7**: `Components.Breadcrumbs.render/2` → always Buffer (no `| []`)
8. **Commit 8**: Create `Components.Message.render/1` → Buffer.t() (MessageInfo → Buffer)
9. **Commit 9**: `Components.ColorWheel.render/1` → Buffer.t() canonical
10. **Commit 10**: `Components.Syntax.highlight_buffer/2` → Buffer.t()

### Phase 3: Fix User-Reported Bugs

11. **Commit 11**: Bug 1 fix — `Show.Message.wrap_with_box` uses Buffer flow
12. **Commit 12**: Bug 2 fix — `AnimatedBar` uses `\e[J` or absolute positioning
13. **Commit 13**: Bug 3 fix — `ImageRenderer.resize_pixels` returns `{r,g,b}` tuples
14. **Commit 14**: Bug 4 fix — `parse_color_opt` handles quoted hex strings
15. **Commit 15**: Bug 5 fix — `alaja color --colors` works without downcase crash

### Phase 4: Action Performance + Bug Fixes

16. **Commit 16**: `Alaja.CLI` — split into `:boot` and `:exec` modes
17. **Commit 17**: `Action.run/1` — uses `:exec` mode for batch elements
18. **Commit 18**: `Action.run/1` — fix implicit stdin TTY hang
19. **Commit 19**: `Action.run/1` — fix `build_args` space splitting
20. **Commit 20**: `Action.run/1` — fix recursion guard case-sensitivity
21. **Commit 21**: `Action.run/1` — add `--parallel`, `--dry-run`, `--stop-on-error`

### Phase 5: Options Parser Hardening

22. **Commit 22**: `OptionsParser` — strict integer/float (returns error tuple)
23. **Commit 23**: `OptionsParser` — `cast_flag_value/2` with `:path`, `:url`, `:color_list`

### Phase 6: Final Hardening

24. **Commit 24**: Config supports env vars (`ALAJAX_*`)
25. **Commit 25**: All CHANGELOG entries for v0.4.0 (next release)
26. **Commit 26**: README updates with all new features
27. **Commit 27**: Tag v0.4.0

## Commit Author / Date Policy

- Author: Lorenzo-SF
- Date: 20:00-22:00 Europe/Berlin (rewrite if outside window)
- Weekday only (weekend free)

## Tests Strategy

- Each smoke test runs as subprocess (`System.cmd("mix", ["alaja", ...])`)
- Captures stdout, strips ANSI escape codes
- Compares to committed `.exs.snap` file
- **Snapshots can ONLY be updated with `mix alaja.snapshot --confirm`**
  (manual review trigger, like Phoenix LiveDashboard)
- No snapshot gets touched without explicit user approval

## Status

- [x] Plan written
- [ ] Phase 1: smoke tests
- [ ] Phase 2: component refactors
- [ ] Phase 3: user bugs
- [ ] Phase 4: action perf
- [ ] Phase 5: parser
- [ ] Phase 6: finalize