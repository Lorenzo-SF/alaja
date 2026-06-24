# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `Alaja.print_raw/1` and `Alaja.print_raw/2` for emitting raw ANSI escapes untouched by the printers.
- `Alaja.CLI.Dispatch` module that centralises dispatch from `Alaja.CLI` into the existing `Alaja.CLI.Commands.*` handlers, isolating them from the DSL.
- New test `test/alaja/cli/dispatch_test.exs` covering all 27 commands.
- `Alaja.CLI.Definition` upgraded to the rich DSL from hex 1.0.0 (flags, arguments, subcommands, `main/1` auto-generated, keyword-style `command/3` with `run: {Mod, :fun}`).
- `Alaja.Config.lookup_theme_color/1` — looks up a key in the active theme. Used by Pote's theme resolver bridge.
- `Alaja.Application` — registers Pote's theme resolver on boot so `Pote.parse("theme:<key>")` consults the active theme.

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
