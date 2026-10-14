# Changelog

All notable changes to Alaja are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.2.1] - 2026-10-14

### Fixed
- **Colour was unconditionally disabled in standalone builds.** A
  batamanta binary, escript, or `mix release` printed plain white text
  with no colour, no bold and no effects even at a fully capable
  terminal. `Alaja.Config.color_enabled?/0` fell back to
  `IO.ANSI.enabled?/0`, which is literally
  `Application.get_env(:elixir, :ansi_enabled, false)` in both Elixir
  1.18 and 1.19 — a bare read with a `false` default and **no** TTY
  detection. That key is written by `Elixir.Kernel.CLI`, which only
  runs for the `elixir`/`mix` launcher, so a release never set it. It
  now falls back to the new `Alaja.Terminal.tty?/0` instead, while an
  explicitly set `:ansi_enabled` still wins — so `mix test`,
  `elixir --color` and `elixir --no-color` are unaffected. This is
  platform-independent: it affected every release build on every OS,
  and only reproduced as "Linux works, macOS does not" because `mix`
  happens to do its own detection.
- **`--force-color` / `--force-colour` did nothing.** The flag parsed
  into `Alaja.CLI.GlobalOpts` and stopped there; no consumer ever read
  it back, and every `Keyword.get(opts, :color)` in the codebase is a
  colour *value*, not a boolean. `Alaja.CLI.NoColor.sync/1` now writes
  `:alaja, :color` = `:always`, which is the key `color_enabled?/0`
  consults first. A monochrome binary could previously not be coaxed
  back into colour by any flag at all.
- **`Alaja.CLI.Picker.run/3` and `Alaja.CLI.Showcase.enabled?/0`** asked
  `IO.ANSI.enabled?/0` directly, so in a release they always took the
  non-interactive path. Both now go through
  `Alaja.Config.color_enabled?/0`.

### Added
- **`alaja.d/alaja.sh`** — install script implementing the shared
  meta-repo contract: `--install` prepares the toolchain, compiles and
  leaves the project ready; `--check` verifies without installing or
  mutating the repo; `--help` prints usage. Reports with the common
  `[✓] ok · [!] aviso · [✗] fallo · [-] omitido` vocabulary. Resolves its
  own symlinks with a `readlink` loop rather than `readlink -f`, which is
  not portable to BSD/macOS, pins toolchain versions from `.tool-versions`
  via `asdf set` when asdf is present, and refuses to install asdf or any
  SDK itself — that belongs to `setup`, and N repos each installing the
  same global toolchain would race.
- **`Alaja.Terminal.tty?/0`** — whether stdout is an interactive
  terminal, cached in `:persistent_term`. Uses
  `File.stat("/dev/fd/1")`, which the kernel resolves against the
  calling process's own descriptors, so it needs no subprocess and is
  correct on Linux and macOS alike. The obvious POSIX probe,
  `sh -c '[ -t 1 ]'`, silently answers the wrong thing: `System.cmd/3`
  and `:erlang.open_port/2` replace the child's fd 1 with a capture
  pipe, so it reports "not a terminal" even at a real one. Probing fd 2
  instead works (stderr is inherited) but tests the wrong descriptor,
  and would write ANSI into a file on `alaja … > out.txt`.

### Changed
- **`mix gen`** now runs `clean_build` first (wiping `_build`, `deps`
  and `mix.lock`) so a stale artifact can never survive into a build.
  It no longer runs an `install` step: alaja is a library consumed
  through `deps`, so there is no symlink to create and pretending
  otherwise made `--check` report a failure on every run.
- **`mix qa`** is a real gate now: `format --check-formatted` instead of
  `format`, `compile --warnings-as-errors --force` instead of `compile`,
  and `credo --strict` added. The old `alaja json "$(mix credo
  --strict --format=json)"` self-render was dropped — it made the QA
  task depend on the very binary under test.

## [3.2.0] - 2026-10-05

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

### Added
- **`alaja table --row-N-<effect> "<bool>;<bool>;..."`** — per-cell
  boolean mask for any effect. The flag's suffix can be `bold`,
  `italic`, `underline`, `dim`, `blink`, `reverse`, `hidden`, or
  `strikethrough`. The value is a `;`-separated list of `true|false`
  cells. `true` keeps the effect (combined with `--rows-effects`);
  `false` opts the cell out. Mask length is short by design — cells
  beyond the list keep the effect.

      alaja table --rows-effects bold \\
        --row-1-bold "true;false;true;true" \\
        --row-2-italic "true;true;false;true"

- **`flag name, type, required: true`** — a flag with `required: true`
  is now validated at dispatch time. If the user omits it (or the
  parser sees `nil`), the CLI exits with
  `Error: missing required flags: --<name>` before the handler runs.
  `validate_flags/2` was previously only enforcing `requires:`
  cross-flag constraints; it now also enforces single-flag `required:`.
- **Unknown-flag rejection with suggestions** — `parse_flags/3` no
  longer silently drops `--foo` arguments that don't match any flag
  in the current command. The parser now emits
  `Error: unknown flag '--foo'` plus up to three
  Jaro-distance-based `Did you mean? --foo, --fooz` suggestions
  drawn from the command's declared flag names. Positional arguments
  still pass through untouched; the gate only fires on `-` / `--`
  prefixed strings.

### Changed
- **`Color.parse_list/1` reverted to `|`-only.** The previous
  `;`-accepting version broke a legacy test that fed
  `rgb:255;0;0` (where `;` is the component separator, not the list
  separator). The new `Color.parse_cell_list/1` does the
  cellwise-aware parsing (accepts both `|` and `;`); the table
  command uses it via `Base.parse_cell_color_list/1`. Generic
  colour lists (`--rows-color`, etc.) keep the strict `|`-only
  contract.
- **`alaja message` parsing is now two-pass.** Strict mode in
  `OptionParser` doesn't collect repeated values, so the strict
  pass validates flag types (`bold`, `padding`, ...) while a
  second non-strict pass pulls out `--text` and `--color` lists
  via `Keyword.get_values/2`. The two-pass is isolated to the
  message command.
- **`Components.Table.Builder.get_row_opts/5` now returns a
  4-tuple** — `{color, effects, align, effect_masks}`. The new
  `effect_masks` map (`%{bold: [true, false, ...], ...}`) feeds
  the per-cell effect filter applied by
  `apply_effect_mask/3`.

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

[3.1.2]: https://hex.pm/packages/alaja/3.1.2
[3.1.1]: https://hex.pm/packages/alaja/3.1.1
[3.1.0]: https://hex.pm/packages/alaja/3.1.0
[3.0.1]: https://hex.pm/packages/alaja/3.0.1
[3.0.0]: https://hex.pm/packages/alaja/3.0.0
[2.4.0]: https://hex.pm/packages/alaja/2.4.0
[Unreleased]: https://github.com/Lorenzo-SF/alaja/compare/3.2.1...HEAD
[3.2.1]: https://github.com/Lorenzo-SF/alaja/compare/3.2.0...3.2.1
[3.2.0]: https://github.com/Lorenzo-SF/alaja/compare/3.1.2...3.2.0
