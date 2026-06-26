# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.8] - 2026-06-27

### Changed
- Bumped `pote` to v0.3.0 in `mix.exs` and `mix.lock`. The v0.2.0 tag
  pointed to a SHA without the `Pote.Theme` heredable system, so
  `mix deps.get` would re-pin to that SHA and `Alaja.Theme` would fail
  to compile with `module Pote.Theme is not loaded`. v0.3.0 of pote
  explicitly tags the release that includes `Pote.Theme`.

## [0.3.7] - 2026-06-27

## [0.3.7] - 2026-06-27

### Fixed
- **BUG**: Escripts (built with `mix gen` + batamanta) never auto-started
  the consumer's OTP application. This meant `Alaja.Application.start/2`
  never ran, which meant `Config.ensure_loaded/0` never ran, which meant
  `:theme_active` was nil in Application env when Pote's theme resolver
  was registered. As a result, every escript saw the default theme's
  colours regardless of `alaja.conf`.
  Repro:
    ```
    alaja config theme set dracula  # writes alaja.conf
    alaja separator --color "theme:ternary"  # always default colours
    ```
  v0.3.6 fixed this for `mix run`-based invocations (which DO auto-start
  the app), but escripts bypass that.
  Fix: `Alaja.CLI.Definition.main/1` now calls
  `Application.ensure_all_started(@otp_app)` before dispatching. This
  ensures `Application.start/2` runs (which does config-load +
  resolver-register in the right order).
  Verified escript flow:
    ```
    alaja config theme set dracula
    alaja separator --color "theme:ternary"  # 255,184,108 (dracula) ✓
    alaja config theme set nord
    alaja separator --color "theme:ternary"  # 235,203,139 (nord)    ✓
    ```

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

[1.0.0]: https://hex.pm/packages/alaja/1.0.0

[0.2.0]: https://github.com/Lorenzo-SF/alaja/releases/tag/v0.2.0
