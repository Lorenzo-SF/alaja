# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-07-01

This release marks a major API shift: alaja is now Buffer-first.
Components that previously returned strings, iodata, or PNG bytes
expose a canonical `Alaja.Buffer.t/0` entry point. PNG/iodata paths
still exist but are now explicit (e.g. `render_for_terminal/2`
returns a tagged tuple) rather than the only option.

### Added
- **`Alaja.Wizard`** — declarative multi-field form renderer. Builds
  a `Buffer.t/0` via one of five neutral renderers:
  `:inline, :compact, :stacked, :wizard, :compact_wizard`. No
  renderer is named after any product, brand, or AI assistant.
  The renderers are pure: same input, same output.
- **`Alaja.Syntax.highlight_buffer/3`** — canonical Buffer-first
  entry point for syntax highlighting. Per-line tokenization
  preserves newlines; ANSI-16 palette is mapped to RGB tuples so
  the Buffer cells carry proper fg colours.
- **`Alaja.Config.load!/1,2`** — path-based config loader with
  optional `:skip_env` (for deterministic tests). Honours the
  `ALAJAX_COLOR_DEPTH` and `ALAJAX_THEME_ACTIVE` env vars as an
  overlay on top of the on-disk JSON.
- **`Alaja.CLI.Definition.cast_flag_value/3` clauses** for `:path`,
  `:url`, and `:color_list` flag types. `:integer` and `:float` no
  longer crash on garbage input — they fall back to the flag's
  default via `Integer.parse/1` and `Float.parse/1`.
- **`alaja multibar`** — new CLI command for multi-task progress tracking with
  parallel bars. Two modes: demo (animated simulation for `--duration` seconds)
  and stdin (interactive pipe protocol with `progress`/`success`/`error`/`wait`/
  `info`/`done` commands). Built on the new `Alaja.Components.MultiBar` GenServer
  component.
- **`Alaja.Components.MultiBar`** — GenServer-based multi-task progress bar
  component. Supports 4 task states (`:running`, `:success`, `:error`, `:wait`),
  per-task progress tracking, dynamic descriptions, and in-place ANSI repaint
  via cursor-up positioning (`\r` + `\e[<n>A` + `\e[J`).

### Changed
- **`Alaja.Components.ColorWheel`** exposes a canonical
  `render/2`, `render_for_terminal/2`, and `default_opts/0` API
  that returns `Buffer.t/0`. The PNG path is now reached through
  `render_for_terminal/2`'s `{:image, iodata}` return value.
- **`Alaja.Syntax.Renderer.Theme`** is now aliased into `Alaja.Syntax`
  so `Theme.resolve/3` is reachable from the new highlight_buffer/3
  without a fully-qualified call.

### Fixed
- **`question_with_options/3`** — the function only matched the user's
  input against the full display label. In practice, typing `1`, `llm`
  or just `Yes` returned `:error` and the wizard dead-ended (this is
  exactly what `delfos setup` hit in production). The function now:
  1. Always lists the options under the prompt with a 1-based index.
  2. Matches, in order: integer index (`1`, `2`), exact label
     (case-insensitive), label prefix (case-insensitive), atom name
     (`llm`, `db`), or `:error`.
  3. New `:default` kwarg chooses a 1-based default index used when
     the user just presses Enter.
  `yesno/2` is rewritten on top of `question_with_options/3`. Now
  `Y` / `N` / `1` / `2` / empty all behave correctly with `:default`
  mapped to the corresponding index.
- **`Alaja.CLI.Definition.cast_flag_value(:integer, "abc", _)`** no
  longer raises ArgumentError. It returns the flag's default.
  Same for `:float`.
- **`Alaja.Components.MultiBar` repaint** — replaced fragile DEC SC/RC (`\e7`/`\e8`)
  with cursor-up (`\r` + `\e[<line_count-1>A` + `\e[J`). The old approach caused
  frames to accumulate on terminals that don't implement the DEC private save/
  restore stack reliably (iTerm2, Terminal.app, Kitty, etc.).
- **BUG**: `alaja color <cualquercosa>` crashed with `ArgumentError: not an iodata term`
  in `Printer.print_raw/2`. Root cause: `Alaja.Components.Table.render/2` was migrated
  to return `Buffer.t/0` in commit 4cd539c but the CLI Color command still embedded the
  Buffer inside an iolist. Fixed by applying `Buffer.to_iodata/1` in `build_color_analysis/3`
  and the extras table block in `lib/alaja/cli/commands/color.ex` (matches the pattern in
  `multi_bar.ex` and `show/bar.ex`).
- **BUG**: `batamanta` dep version bumped from 1.5.1 to 1.6.0 (mix.lock updated).

### Migration
- If you called `ColorWheel.render/2` (returning iodata), migrate to
  `ColorWheel.render_for_terminal/2` and pattern-match on the tagged
  tuple. Or use the new `ColorWheel.render/2` which returns
  `Buffer.t/0`.
- If you wrote `cast_flag_value/3` test fixtures, the new
  `:path, :url, :color_list` types now exist; the failure mode for
  bad `:integer/:float` input has changed from "raise" to "fall back
  to default".

[1.0.0] was tagged on the first commit (`1472b5f`) but the published
artifact was lost — see hex.pm docs to invalidate. This 2.0.0 release
is the canonical version going forward.

## [0.3.10] - 2026-06-27

### Fixed
- **LINT**: `__before_compile__/1` macro no longer generates dead `if` block
  when `@halt_on_error` is `false`, eliminating a compiler warning about a
  conditional that always evaluates to `dynamic(false)`.
- **LINT**: `dispatch/2` now has a proper `@spec` so external consumers
  get a known return type instead of `dynamic()`, preventing type-checker
  warnings when pattern-matching the result.

## [0.3.9] - 2026-06-27

### Fixed
- **BUG**: `dispatch_main/1` never started the OTP application, so
  `Theme.register_with_pote/0` was never invoked in escript mode,
  leaving the theme resolver stack empty on every fresh process and
  causing all `"theme:xxxx"` lookups to fall back to Pote's hardcoded
  defaults regardless of the persisted theme.
- **BUG**: `subcommand` DSL macro produced flat `@commands` entries
  with `subcommands: %{}` — inner `command` macros accumulated at the
  top level instead of being nested under the parent, making the
  documented `subcommand`/`command` pattern non-functional.
- **BUG**: 14 `System.halt(1)` calls in library-accessible paths
  killed the entire BEAM when used as a library; replaced with
  `exit({:shutdown, 1})`.
- **BUG**: `Json.render/2` produced non-deterministic key order for
  maps; keys are now sorted recursively via `Jason.OrderedObject`.
- **BUG**: Division by zero in `Pulsar.render_frame/3` when
  `pulse_chars: []` was passed.
- **LINT**: All 7 compiler warnings eliminated (unused variables,
  ungrouped function clauses, never-match patterns, dead code).
- **LINT**: All Credo `--strict` issues resolved (cyclomatic complexity,
  alias ordering, `cond` → `if`, implicit `try`/`catch`).

## [0.3.6] - 2026-06-27

### Fixed
- **BUG**: Every escript started with `:theme_active` unset in
  Application env, even when `alaja config theme set <name>` had
  persisted the user's choice to `alaja.conf`. As a result, every
  `theme:<key>` lookup (and `Pote.parse(:success)` etc.) returned the
  default theme's colour regardless of the persisted setting.
  Repro:
    ```
    alaja config theme set dracula  # writes alaja.conf
    alaja separator --color "theme:ternary"
    # ^ in a NEW process — ternary is wrong colour (default, not dracula)
    ```
  Root cause: `Alaja.Application.start/2` registered Pote's theme
  resolver before loading the on-disk config. The resolver reads
  `Application.get_env(:alaja, :theme_active, "default")` at lookup time
  — but in a fresh process, that env var was nil until something
  called `Alaja.Config.ensure_loaded/0` (which `Config.get/2` does
  transparently, but `Pote.parse/1` does not).
  Fix: `Alaja.Application.start/2` now calls
  `Alaja.Config.ensure_loaded/0` BEFORE `Theme.register_with_pote/0`.
  `Config.ensure_loaded/0` is now public (was `defp`).
  Verified cross-process: setting dracula in process 1 + reading
  `theme:ternary` in process 2 now returns dracula's
  `{255, 184, 108}` (not the default `{255, 128, 0}`).

### Tests
- Added 3 regression tests in `test/alaja/theme_switching_test.exs`:
  - `persisted theme_active is honoured in this process` — simulates a
    fresh process by wiping Application env, calling `ensure_loaded/0`,
    and verifying `theme:ternary` resolves to the persisted theme.
  - `Config.ensure_loaded/0 is callable as a public function` —
    verifies the function is exported (so Application.start/2 can call
    it).
  - `Application.start/2 source order is config-load-then-resolver-register`
    — verifies the call order in the source code (cheap structural
    test that survives future refactors).

Total: 606 tests, 0 failures.

## [0.3.5] - 2026-06-27

### Fixed
- **BUG**: `alaja config theme set <name>` did NOT change the colour
  palette used by `theme:<key>` lookups or atom lookups (`:success`,
  `:error`, `:warning`, etc.). Whatever theme the user selected, the
  colours stayed the same — `print_success` always rendered green,
  `print_error` always rendered red, etc.
  Root cause: `alaja config init` was writing hand-rolled theme JSON
  files with the legacy `{"rgb": [r,g,b]}` wrapper format. Pote's
  resolver expected flat `[r,g,b]` arrays. So every lookup returned
  `:not_found` and fell back to Pote's hardcoded `@default_colors`,
  independent of which theme was "active".
  Plus, the hand-rolled themes only had 11 colour keys each
  (primary, secondary, ternary, quaternary, success, warning, error,
  info, no_color, background — and not all 11 in every theme). Missing
  keys: `debug`, `happy`, `sad`, `menu`, `alert`, `critical`,
  `gradient_1..6`.
- **BUG**: `alaja config theme list` listed files from disk directly
  instead of consulting `Alaja.Theme.list/0`. The two could disagree.

### Changed
- `alaja config init` now calls `Alaja.Theme.install_template/1` for
  every built-in Pote template (default, dracula, monokai, nord,
  light). Each template has the full 22-key colour set and is written
  in the correct flat `[r,g,b]` format that Pote's resolver expects.
- `alaja config theme set NAME` now calls `Alaja.Theme.activate/1`
  which writes through to `:theme_active` and re-registers Pote's
  resolver. Both `Pote.parse(:success)` (atom) and
  `Pote.parse("theme:success")` (string) now reflect the active theme.
- `alaja config theme list` now uses `Alaja.Theme.list/0` as the
  single source of truth.
- Deleted 135 lines of hand-rolled theme definitions from
  `lib/alaja/cli/commands/config.ex`. Single source of truth is
  `Pote.Theme.Templates`.

### Tests
- Added `test/alaja/theme_switching_test.exs` with 8 regression tests:
  - `install_template/1` writes JSON in flat `[r,g,b]` format
  - Every template has the full 22-key colour set
  - `activate/1` makes `Pote.parse(:atom)` return different RGB tuples
    per theme (default vs dracula vs nord vs light)
  - `activate/1` makes `Pote.parse("theme:<key>")` return different
    RGB tuples per theme
  - Every key (`debug`, `happy`, `sad`, `gradient_1..6`) is theme-aware
  - `Alaja.print_success` uses the active theme's colour
  - `Alaja.print_error` uses the active theme's colour
  - `Theme.list/0` returns the installed templates

## [0.3.4] - 2026-06-26

### Fixed
- **BUG**: `Alaja.Printer.print_raw/2` crashed with `ArgumentError: not an iodata term`
  whenever the input was a `Buffer.t()` and the `:box` opt was set. Affects
  every Cell-engine component used through the CLI with `--box`:
  - `alaja json --box`
  - `alaja header --box`
  - `alaja gradient --box`
  - `alaja table --box` (uses `render_buffer/2`)
  - `alaja bar --box`, `alaja breadcrumbs --box`, `alaja separator --box`
  Root cause: `print_raw/2` would call `Box.render/2` on the *iodata*
  representation of the buffer, get back a `Buffer.t()`, and then try
  `IO.iodata_to_binary(buffer)` which fails because `Buffer.t()` is not
  iodata. Fix: `print_raw/2` now applies box wrapping at the Buffer
  level (when input is a Buffer) so ANSI coalescing is preserved end-to-end.
  For string/iodata input, `Box.render/2` is still called on the converted
  binary, but the returned Buffer is converted back via
  `Buffer.to_iodata/1 |> IO.iodata_to_binary/1`. Added internal
  `:_box_applied` flag to prevent double-wrapping when input was a Buffer.

### Tests
- Added `test/alaja/print_raw_buffer_test.exs` with 12 regression tests
  covering the Buffer + box path for all Cell-engine components.

## [0.3.1] - 2026-06-25

### Fixed
- **BUG**: `Alaja.CLI.Definition.main/1` used to call `System.halt/1` whenever
  the dispatcher hit an error (unknown command, no command, missing arg,
  invalid flag, missing flag value, no handler, invalid global flag value).
  This made the framework unusable as a library — calling `main/1` from
  tests or from another module would kill the BEAM with exit code 1.
  Now the dispatcher returns `{:error, reason}` and the framework's
  `main/1` only halts if the consumer opted in via
  `use Alaja.CLI.Definition, otp_app: :my_app, halt_on_error: true`
  (the default, kept for backwards-compatible escript behaviour). To load
  as a library without `System.halt`:
  `use Alaja.CLI.Definition, otp_app: :my_app, halt_on_error: false`.

## [0.3.0] - 2026-06-25

### Added — Cell/Buffer engine unification
The terminal rendering engine is now unified around `Alaja.Buffer` as the
single source of truth for 2D layout. Components return `Buffer.t()` from
`render/N` instead of opaque iodata. This unlocks composition (overlay,
hstack, vstack, crop, pad, with_offset) and precise positioning.

#### Composition primitives in `Alaja.Buffer`
- `Buffer.to_iodata/1` — emits ANSI-optimised iodata, coalescing
  consecutive cells with the same style into one escape sequence.
- `Buffer.overlay/4` — paint `src` onto `dest` at `(x, y)`, clipping
  out-of-bounds cells. Empty cells in `src` don't overwrite `dest`.
- `Buffer.hstack/2` — horizontal stack with optional gap.
- `Buffer.vstack/2` — vertical stack with optional gap.
- `Buffer.crop/5` — sub-region with bounds clamping.
- `Buffer.pad/3` — grow to target size, content stays top-left.
- `Buffer.with_offset/3` — attach logical `(x, y)` metadata for
  layout composition without copying cells.

#### New `Alaja.Printer.print_buffer/2`
Prints a buffer to stdout at `(x, y)` (via ANSI cursor escapes). Honors
`buffer.offset_x/offset_y` plus the `:x`/`:y` options.

#### Components moved to the Cell engine
- `Alaja.Components.Separator.render/2` → `Buffer.t()`
- `Alaja.Components.Bar.render/3` → `Buffer.t()`
- `Alaja.Components.Breadcrumbs.render/2` → `Buffer.t()`
- `Alaja.Components.Header.render/2` → `Buffer.t()`
- `Alaja.Components.Json.render/2` → `Buffer.t()` (tokenizer-based)
- `Alaja.Components.Box.render/2` → `Buffer.t()` and **accepts a
  `Buffer.t()` as content**, returning a Buffer-in, Buffer-out
  pipeline (the foundation of Box-as-transversal-wrapper).

#### New `Alaja.Components.Table.render_buffer/2`
The Cell-engine variant of Table rendering. Supports layout-level
options (column widths, alignment, header/row colors, border styles).
For exotic per-cell/row/column formatting, `Table.render/2` still
returns iodata. Pagination remains in `Table.print/2`.

#### Tests
- 18 snapshot tests under `test/alaja/snapshot_test.exs` capturing
  the visual output of every component before/after the refactor.
- 32 cell-engine tests under `test/alaja/cell_engine_test.exs`
  covering composition (overlay, hstack, vstack, crop, pad,
  with_offset), `Buffer.to_iodata/1`, `Printer.print_buffer/2`, and
  end-to-end composition (Box around a Table, Header inside a Box,
  Separator stacked on a Bar).
- Updated `test/alaja/components/components_test.exs` to expect
  `Buffer.t()` instead of iodata from `render/N`.

### Changed
- `Alaja.Components.Box.render/2` now returns a `Buffer.t()` (not
  iodata). All call sites that previously used
  `IO.iodata_to_binary(Box.render(...))` should switch to
  `Buffer.to_iodata(Box.render(...)) |> IO.iodata_to_binary()` or
  just call `Box.print/2`.
- `Alaja.Components.Table.render/2` still returns iodata for
  backward compatibility (exotic formatting options). Use
  `Table.render_buffer/2` for the Cell-engine version.
- `Alaja.Printer.print_raw/2` now accepts both `Buffer.t()` and
  iodata; the Buffer path uses `Buffer.to_iodata/1` internally.

### Migration notes
- Downstream consumers (Delfos, Apero, etc.) only use `X.print(...)`
  and `Alaja.print_raw(string)`, both of which are unchanged. **Zero
  breaking changes for the ecosystem.**
- If you call `render/N` directly and expect iodata, wrap with
  `Buffer.to_iodata/1`. If you want to compose components, pass
  Buffers to `Box.render/2` or use `Buffer.overlay/4` /
  `Buffer.hstack/2` / `Buffer.vstack/2`.

## [0.2.0] - 2026-06-24

### Added
- **`Alaja.Theme`** — facade generated by `use Pote.Theme, config_app: :alaja`. Exposes `list/0`, `active/0`, `activate/1`, `color/1`, `colors/0`, `install!/1`, `install_template/1`, `templates/0`. Themes live under `~/.config/alaja/themes/` (or `ALAJA_THEMES_PATH` env var). Auto-registers its resolver with `Pote` on application start so `Pote.parse("theme:<key>")` consults Alaja's active theme.
- `Alaja.print_raw/1` and `Alaja.print_raw/2` for emitting raw ANSI escapes untouched by the printers.
- `Alaja.CLI.Dispatch` module that centralises dispatch from `Alaja.CLI` into the existing `Alaja.CLI.Commands.*` handlers, isolating them from the DSL.
- New test `test/alaja/cli/dispatch_test.exs` covering all 27 commands.
- `Alaja.CLI.Definition` upgraded to the rich DSL from hex 1.0.0 (flags, arguments, subcommands, `main/1` auto-generated, keyword-style `command/3` with `run: {Mod, :fun}`).
- `Alaja.Config.lookup_theme_color/1` — looks up a key in the active theme. Used by Pote's theme resolver bridge.
- `Alaja.Application` — registers Pote's theme resolver on boot so `Pote.parse("theme:<key>")` consults the active theme.
- `Alaja.run/1` and `Alaja.run/2` — unified entry point for running any Alaja-based CLI. Default `cli_module` is `Alaja.CLI`; pass any module built with `use Alaja.CLI.Definition, otp_app: :my_app` to run your own. Replaces ad-hoc `cli_module.main/1` calls.

### Fixed
- **BUG**: `alaja separator --color "theme:ternary"` (and any other command going through `Pote.Orchestrator.parse_color("theme:<key>")`) used to ignore the active theme and always return Pote's hardcoded `@default_colors`. It now returns the active theme's color. Same fix applies to atom lookups like `:ternary`.

### Changed
- **i18n**: translated remaining Spanish docstrings and inline comments to English across the library for consistency.
- **Self-hosting**: `Alaja.CLI` now uses `use Alaja.CLI.Definition` to define its commands, replacing the manual `command_dispatch/0` and `command_descriptions/0` maps. The CLI is built with its own framework.
- `Pote.Conversions.*` calls in `Alaja.CLI.Commands.Color` migrated to the new `Pote.Converters.Advanced.*` and `Pote.Converters.RGB.*` API to avoid deprecation warnings.
- `Alaja.Helpers` no longer exposes the 11 deprecated ANSI wrappers. Internal helpers (`progress_bar`, `box`, `double_box`) now call `Alaja.ANSI.*` directly. Consumers should migrate to `Alaja.ANSI`.
- The DSL `run` macro now accepts `{module, function}` tuples (instead of arbitrary anonymous functions), making handlers composable and inspectable.

### Removed
- Deprecated `Alaja.Helpers.{move,clear,hide_cursor,show_cursor,clear_line,fg,bg,bold,dim,italic,reset}` wrappers (use `Alaja.ANSI.*` directly).

## [1.0.0] - 2026-06-10

### Added
- Initial open source release: DSL, components, rendering, syntax highlighting, ANSI utilities.

[v0.3.10]: https://github.com/Lorenzo-SF/alaja/releases/tag/v0.3.10
[v0.3.9]: https://github.com/Lorenzo-SF/alaja/releases/tag/v0.3.9
[1.0.0]: https://hex.pm/packages/alaja/1.0.0

[0.2.0]: https://github.com/Lorenzo-SF/alaja/releases/tag/v0.2.0
