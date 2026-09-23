# Changelog

All notable changes to Alaja are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **`alaja message` help**: now goes through `HelpFormatter.render/2`
  via `@help_data` (mirrors `gradient`/`header`). Adds usage,
  description, options table, and examples sections.
- **`alaja message --text X --color Y --text Z --color W` prints all
  chunks**: `--text` and `--color` are now repeatable in `OptionParser`
  (strict mode). Chunks are paired positionally; overflow colours
  fall back to the type's default.
- **`alaja table --row-N-color "red;blue;green"` applies one colour
  per cell**: `Color.parse_list/1` now accepts `;` (alongside `|`) as
  the colour separator. `parse_list/1` splits on `|` first, then on
  `;` per part. Tests for both separators and mixed mode added.
- **`alaja table` default border**: aligned the runtime default with
  what `help_data` advertises (`rounded`).
- **Host-aware CLI isolation**: a synthetic host module test
  (`test/alaja/cli/host_aware_test.exs`) locks the contract that
  `__commands__/0` and `__otp_app__/0` are per-module — alaja's
  command catalogue cannot leak into a host that consumes
  `Alaja.CLI.Definition` as a library.

## [3.1.2] — 2026-09-18

### Fixed
- **Host-aware CLI help**: `Alaja.CLI.Definition` threads `otp_app`
  through `run_dispatch`, so external apps (e.g. `arrea --help`)
  render their own command summary and banner instead of Alaja's
  full command reference. `arrea --version` now reports the host
  app version instead of `alaja 3.0.0`.
- Restored the `render/1` clause for non-empty `MessageInfo`
  (dropped during a merge) and fixed `resolve_with_pote` to return
  a function value.
- `Alaja.CLI.Message.render/3` accepts maps and reads `opts[:text]`;
  fixed `KeyError :bg_color`, `Range` step in guards, and Credo
  complexity in picker/compare paths.

### Changed
- CI hardened with a strict sentinel (format → credo → test →
  dialyzer → audit split); dialyzer and legacy smoke tests are
  non-blocking until the legacy cleanup pass lands.
- `mix.exs`: sibling dep is now the Hex requirement
  `{:pote, "~> 3.0"}` (was `git:`); `source_ref` points at `3.1.2`.

## [3.1.1] — 2026-09-13

### Added
- Theme JSON accepts arbitrary custom keys and any colour format
  in theme values.

## [3.1.0] — 2026-09-13

### Changed
- Redesigned the `alaja theme` command around a dynamic
  colour-format table.

## [3.0.1] — 2026-09-13

### Fixed
- Brought pre-existing components within `credo --strict`.
- Startup showcase yes/no prompt is arrow-key aware (`:up`/`:down`,
  vim `j`/`k`, `1`/`2`, `y`/`n`, Enter, `q`/Esc).

## [3.0.0] — 2026-09-13

### Changed
- Switched the project packaging from `mix escript` to a Mix
  release packaged by Batamanta. No API change for library users.
- `mix.exs` now declares the project as a release
  (`batamanta: [format: :release, ...]`) and the legacy
  `escript: [main_module: Alaja.CLI]` entry has been removed.
- The compiled artefact is still a self-contained, single-file
  binary named `alaja` and is installed by `mix gen` to
  `~/bin/alaja` exactly as before. The difference is internal: the
  binary now embeds an OTP release (with its ERTS, app graph and
  release scripts) rather than a flat escript.
- Docstrings and comments that previously referred to the escript
  format (in `lib/alaja.ex`, `lib/alaja/cli/definition.ex`,
  `lib/alaja/application.ex`, `lib/alaja/config.ex`, and
  `test/alaja/theme_switching_test.exs`) have been updated to
  reflect the new release format.
- `docs/ARCHITECTURE.md`, `docs/AUDIT.md`, and the bilingual
  READMEs now describe the release pipeline instead of the
  escript one.

### Added
- Alaja 3.0 maturity pass (AL-10/11/12): `Printer` split into
  format / raw I/O / dispatcher, CLI logic extracted to
  `Components.Animate`, `Components.Gradient` and
  `Components.List`, shared 16-colour ANSI constants module,
  Buffer-returning box variants, and Pote theme-atom colour
  resolution in components.
- 12 custom colour themes (catppuccin, solarized, gruvbox,
  tokyo-night, everforest, rose-pine, ayu, synthwave, aurora,
  material-ocean, outrun, kanagawa).

## [2.4.0] — 2026-09-10

### Added
- `@doc` coverage for previously undocumented `show` + dispatch
  public functions.

### Fixed
- Dialyzer contract/pattern errors, unused variable/alias
  warnings, and `animate_filled/5 :rainbow` Credo complexity.

[v3.1.2]: https://hex.pm/packages/alaja/3.1.2
[v3.1.1]: https://hex.pm/packages/alaja/3.1.1
[v3.1.0]: https://hex.pm/packages/alaja/3.1.0
[v3.0.1]: https://hex.pm/packages/alaja/3.0.1
[v3.0.0]: https://hex.pm/packages/alaja/3.0.0
[2.4.0]: https://hex.pm/packages/alaja/2.4.0
[Unreleased]: https://github.com/Lorenzo-SF/alaja/compare/v3.1.2...HEAD
