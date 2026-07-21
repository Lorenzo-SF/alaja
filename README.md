# Alaja — Declarative CLI framework & terminal rendering kit for Elixir

[![Hex version](https://img.shields.io/badge/hex-2.4.0-blue.svg)](https://hex.pm/packages/alaja)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.md)
[![Version](https://img.shields.io/badge/version-2.4.0-blue.svg)](https://github.com/Lorenzo-SF/alaja)

<p align="center">
  <img src="https://raw.githubusercontent.com/Lorenzo-SF/alaja/main/docs/batamantaman_alaja.png" width="400" alt="Alaja" />
</p>

Alaja is a declarative CLI framework and terminal rendering kit for Elixir.
Define commands with a DSL, validate flags, auto-generate help, and render
rich terminal output — tables, headers, boxes, bars, breadcrumbs, JSON
syntax highlighting, gradients, and interactive prompts — all powered by
true-color ANSI escape sequences.

Alaja is a standalone CLI framework and terminal rendering kit. It depends on
[Pote](https://github.com/lorenzo-sf/pote) for colour management, theme
resolution, and format conversions.

---

## Quick Start

Add `alaja` and `pote` to your `mix.exs`:

```elixir
def deps do
  [
    {:alaja, github: "Lorenzo-SF/alaja"}
    {:pote, github: "Lorenzo-SF/pote"}
  ]
end
```

### `halt_on_error` (v0.3.3+)

By default, `Alaja.CLI.Definition` does NOT call `System.halt/1` on
dispatch errors (unknown command, missing arg, invalid flag). This
makes the DSL safe to use as a library — calling `main/1` from a
test or from another module won't kill the BEAM.

For escript-style behaviour (exit code 1 on error), opt in explicitly:

```elixir
use Alaja.CLI.Definition, otp_app: :my_app, halt_on_error: true
```

When `halt_on_error: false` (the default), `main/1` returns
`{:error, reason}` where `reason` is one of `:no_command`,
`:unknown_command`, `:no_handler`, `:invalid_command`, etc.

### Define a CLI in 5 minutes

```elixir
defmodule MyApp.CLI do
  use Alaja.CLI.Definition, otp_app: :my_app, halt_on_error: true

  command "deploy", "Deploy to production" do
    flag :env, :string, default: "staging", values: ~w(staging production)
    flag :force, :boolean, default: false
    argument :version, :string, required: true

    run fn opts ->
      Alaja.print_success("Deploying v#{opts.version} to #{opts.env}...")
      if opts.force, do: Alaja.print_warning("Force mode enabled!")
    end
  end

  command "status", "Show system status" do
    run fn _opts ->
      Alaja.Components.Table.print(
        headers: ["Service", "Status", "Uptime"],
        rows: [
          ["api",     "OK",    "12d 4h"],
          ["db",      "OK",    "30d 2h"],
          ["cache",   "WARN",  "2h 15m"]
        ],
        table_border: :rounded,
        rows_2_color: [:white, :yellow, :white]
      )
    end
  end
end
```

Run it:

```bash
mix run -e 'MyApp.CLI.main(["deploy", "1.2.3"])'
mix run -e 'MyApp.CLI.main(["deploy", "1.2.3", "--env", "production", "--force"])'
mix run -e 'MyApp.CLI.main(["status"])'
```

---

## Rendering Layer

### Message printing (12 severity levels)

```elixir
Alaja.print_success("Deploy completed!")      # ✓ green
Alaja.print_error("Connection refused")        # ✗ red bold
Alaja.print_warning("Disk usage above 80%")    # ⚠ yellow
Alaja.print_info("Processing 12 files...")     # ℹ cyan
Alaja.print_debug("PID: 0.1234.5")             # ⚙ purple
Alaja.print_notice("Maintenance at 02:00")     # 📢 blue
Alaja.print_alert("CPU spike detected!")       # 🔔 inverted warning
Alaja.print_critical("Database unreachable!")  # 🔥 inverted error
Alaja.print_emergency("System crash!")         # 🆘 blinking
Alaja.print_happy("All tests passed!")         # ✨
Alaja.print_sad("Build failed again...")       # ❄

# Dynamic dispatch
Alaja.Printer.print_message(:success, "Done!")
Alaja.Printer.print_message(:error, "Oops!")
```

| Function              | Icon | Style          |
| --------------------- | ---- | -------------- |
| `print_success/1,2`   | ✓    | Green          |
| `print_error/1,2`     | ✗    | Red bold       |
| `print_warning/1,2`   | ⚠    | Yellow         |
| `print_info/1,2`      | ℹ    | Cyan           |
| `print_debug/1,2`     | ⚙    | Purple         |
| `print_notice/1,2`    | 📢   | Blue           |
| `print_alert/1,2`     | 🔔   | Inverted warn  |
| `print_critical/1,2`  | 🔥   | Inverted error |
| `print_emergency/1,2` | 🆘   | Blinking       |
| `print_happy/1,2`     | ✨   | Happy theme    |
| `print_sad/1,2`       | ❄    | Sad theme      |
| `print_message/2`     | —    | Dynamic level  |

All functions accept printer options: `raw: true`, `x:`, `y:`, `align:`,
`verbose:`, `padding:`.

### Interactive input

```elixir
alias Alaja.Printer.Interactive

name   = Interactive.question("What's your name?")
answer = Interactive.yesno("Continue?", default: :no)
result = Interactive.question_with_options("Pick:", [{"Yes", :yes}, {"No", :no}])
Interactive.menu("Select action:", [{"Deploy", :deploy}, {"Rollback", :rollback}])
```

### Printer API (low-level)

```elixir
# Structured message printing with chunks
chunks = [
  Alaja.Structures.ChunkText.new(" Error: ", color: :error, effects: [:bold]),
  Alaja.Structures.ChunkText.new("File not found", color: :white)
]
msg = Alaja.Structures.MessageInfo.new(chunks, align: :center, padding: 2)
Alaja.Printer.print(msg)

# Raw positioning
Alaja.Printer.print("Loading...", raw: true, x: 10, y: 5)

# Verbose mode returns ANSI string
ansi = Alaja.Printer.print("Hello", verbose: true)
```

### Structures

| Structure     | Module                         | Purpose                         |
| ------------- | ------------------------------ | ------------------------------- |
| `ChunkText`   | `Alaja.Structures.ChunkText`   | Text fragment + color + effects |
| `EffectInfo`  | `Alaja.Structures.EffectInfo`  | Bold, italic, blink, etc.       |
| `MessageInfo` | `Alaja.Structures.MessageInfo` | Compound message + layout opts  |

```elixir
chunk = Alaja.Structures.ChunkText.new("Hello", color: "#FF0000", effects: [:bold, :underline])
effects = Alaja.Structures.EffectInfo.new([:bold, :italic, :blink])
msg = Alaja.Structures.MessageInfo.new([chunk], align: :center, padding: 4)
```

---

## CLI Framework

### DSL (`Alaja.CLI.Definition`)

The declarative DSL provides `command`, `subcommand`, `flag`, `argument`,
and `run` macros:

```elixir
defmodule MyApp.CLI do
  use Alaja.CLI.Definition, otp_app: :my_app, halt_on_error: true

  command "build", "Build the project" do
    flag :release, :boolean, default: false
    flag :arch, :string, default: "amd64", values: ~w(amd64 arm64)
    argument :target, :string, required: true

    run fn opts ->
      IO.puts("Building #{opts.target} for #{opts.arch}...")
    end
  end

  subcommand "config", "Manage configuration" do
    command "get", "Read a value" do
      argument :key, :string, required: true

      run fn opts ->
        value = Alaja.Config.get(String.to_atom(opts.key))
        IO.puts("#{opts.key}: #{inspect(value)}")
      end
    end

    command "set", "Write a value" do
      argument :key, :string, required: true
      argument :value, :string, required: true

      run fn opts ->
        Alaja.Config.set(String.to_atom(opts.key), opts.value)
        Alaja.print_success("#{opts.key} = #{opts.value}")
      end
    end
  end
end
```

Flag types: `:string`, `:integer`, `:float`, `:boolean`, `:atom`.

### Global options (`Alaja.CLI.GlobalOpts`)

12 flags shared by all commands, extracted automatically before command
dispatch:

| Flag           | Short | Type                | Description                          |
| -------------- | ----- | ------------------- | ------------------------------------ |
| `--help`       | `-h`  | boolean             | Show help                            |
| `--raw`        | `-r`  | boolean             | Raw ANSI positioning                 |
| `--pos-x`      |       | integer             | X coordinate (with `--raw`)          |
| `--pos-y`      |       | integer             | Y coordinate (with `--raw`)          |
| `--align`      | `-a`  | `left/center/right` | Text alignment                       |
| `--verbose`    | `-v`  | boolean             | Return ANSI string                   |
| `--box`        |       | boolean             | Wrap output in a bordered box        |
| `--box-title`  |       | string              | Box title                            |
| `--box-border` |       | atom                | Border style: `rounded`, `double`... |
| `--box-color`  |       | color               | Border color                         |
| `--quiet`      | `-q`  | boolean             | Suppress output                      |
| `--stdin`      | `-s`  | boolean             | Read JSON from stdin                 |

### Help system (`Alaja.CLI.Help`)

Auto-generated help with summary, full reference, and per-command help —
all rendered with Alaja's own table and header components.

### Validation (`Alaja.CLI.Validator`)

```elixir
# Flag type checking
Alaja.CLI.Validator.validate_flags([%{name: :port, type: :integer, required: true}],
                                    [port: "abc"])
# => {:error, ["--port: expected integer, got 'abc'"]}

# Allowed values
Alaja.CLI.Validator.validate_flags([%{name: :env, values: ~w(staging prod)}],
                                    [env: "dev"])
# => {:error, ["--env: 'dev' is not valid. Allowed: staging, prod"]}

# Missing required args
Alaja.CLI.Validator.validate_args([%{name: :version, required: true}], [])
# => {:error, ["Missing required argument: version"]}

# Dangerous command detection
Alaja.CLI.Validator.dangerous?("rm -rf /")
# => true
```

### Error handling (`Alaja.CLI.ErrorHandler`)

Formatted error messages with "did you mean?" suggestions using Jaro
distance, plus proper exit codes:

```bash
$ mycli deploi
Error: unknown command 'deploi'

Did you mean?
  deploy

Available commands:
  deploy              Deploy to production
  status              Show system status
```

### Parser utilities (`Alaja.CLI.Parser`)

```elixir
# Collect repeated flags
Alaja.CLI.Parser.collect_repeated(~w(--cmd ls --cmd pwd), "--cmd")
# => ["ls", "pwd"]

# Parse colors
Alaja.CLI.Parser.parse_color("#FF0000")
# => {:ok, {255, 0, 0}}

# Parse color lists
Alaja.CLI.Parser.parse_color_list("#FF0000; #00FF00; #0000FF")
# => {:ok, [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}]}

# Parse KEY=VALUE pairs
Alaja.CLI.Parser.parse_env_pair("PATH=/usr/bin")
# => {:PATH, "/usr/bin"}

# Parse alignment
Alaja.CLI.Parser.parse_align("center")
# => :center
```

### Built-in commands reference

**`Alaja.CLI.Commands.Show`** — 16 output subcommands:

| Subcommand     | Description                                        |
| -------------- | -------------------------------------------------- |
| `success`      | Success message with green checkmark               |
| `error`        | Error message with red cross                       |
| `warning`      | Warning message with yellow triangle               |
| `info`         | Info message with cyan indicator                   |
| `debug`        | Debug message with purple indicator                |
| `notice`       | Notice message with blue indicator                 |
| `critical`     | Critical message with magenta indicator            |
| `alert`        | Alert message with red indicator                   |
| `emergency`    | Emergency message with blinking indicator          |
| `happy`        | Happy message with green indicator                 |
| `sad`          | Sad message with blue indicator                    |
| `message`      | Custom formatted message (chunks, colors, effects) |
| `table`        | Rich tables with borders, per-cell styling         |
| `json`         | Pretty-printed JSON with syntax highlighting       |
| `bar`          | Progress bar with customizable appearance          |
| `animated-bar` | Animated progress bar                              |
| `header`       | Styled header with optional subtitle               |
| `separator`    | Horizontal divider line with optional text         |
| `gradient`     | Gradient-colored text (multi-color support)        |
| `breadcrumbs`  | Navigation path display                            |
| `box`          | Bordered container with optional title             |
| `animate`      | Animated spinners and indicators                   |
| `image`        | Render images (kitty/iterm2/sixel/ASCII)           |
| `list`         | Styled list with optional header                   |
| `ask`          | Interactive text input                             |
| `menu`         | Interactive selection menu                         |
| `multibar`     | Multi-task progress tracker with parallel bars     |
| `yesno`        | Interactive yes/no question                        |

**`Alaja.CLI.Commands.Theme`** — Theme management (replaces the deprecated `config` command):

| Action           | Description                                          |
| ---------------- | ---------------------------------------------------- |
| `init`           | Install built-in + custom templates to `~/.config/alaja/themes` |
| `list`           | List installed themes                                |
| `set NAME`       | Activate a theme by name                            |
| `show`           | Show the active theme's colour map                   |

The legacy `alaja config` command is deprecated and prints a notice
pointing at `alaja theme` (see `lib/alaja/cli/commands/config.ex`).

---

## Multi-field forms (`Alaja.Wizard`, v2.0.0+)

`Alaja.Wizard` is a declarative, multi-field form renderer. It is
pure data — no I/O — and renders to an `Alaja.Buffer.t/0` via one
of five **neutral** renderers:

  :inline           single line, comma-separated
  :compact          two-column table (label | value)
  :stacked          label above value, blank line between fields
  :wizard           boxed form with a top progress marker
  :compact_wizard   boxed, single-line form

```elixir
w =
  Alaja.Wizard.new(title: "Profile")
  |> Alaja.Wizard.field(:name, :string, label: "Name", default: "alice")
  |> Alaja.Wizard.field(:age, :integer, label: "Age", default: 30)
  |> Alaja.Wizard.field(:newsletter, :boolean, label: "Subscribe", default: true)

Alaja.Wizard.render(w, :compact) |> Alaja.Printer.print_raw()
```

The renderer identifiers are deliberately generic and reusable. No
renderer is named after any product, brand, or AI assistant — so
downstream consumers can rely on the same five names regardless of
which feature they are embedding.

---

## Visual Components

| Module                         | Description                                   |
| ------------------------------ | --------------------------------------------- |
| `Alaja.Components.Table`       | Bordered tables, per-cell/col/row formatting  |
| `Alaja.Components.Header`      | Centered title + subtitle, 3 sizes            |
| `Alaja.Components.Separator`   | Horizontal rules with optional centered label |
| `Alaja.Components.Bar`         | Static progress bars, RGB gradients           |
| `Alaja.Components.AnimatedBar` | GenServer-based animated bars (8 styles)      |
| `Alaja.Components.MultiBar`    | GenServer-based multi-task progress bar        |
| `Alaja.Components.Breadcrumbs` | Path navigation with customizable separator   |
| `Alaja.Components.Box`         | Bordered containers (5 border styles)         |
| `Alaja.Components.Json`        | Pretty-printed JSON with syntax highlighting  |
| `Alaja.Components.ColorWheel`  | HSL wheel, harmony rings, swatches, gradients |
| `Alaja.Components.Gradient`    | Horizontal colour ramps via ColorWheel        |

### Examples

**Table** — per-column formatting, specific row styling, centered:

```elixir
Alaja.Components.Table.print(
  headers: ["Service", "Status", "Uptime"],
  rows: [
    ["api",    "OK",     "12d"],
    ["db",     "OK",     "30d"],
    ["cache",  "WARN",   "2h"]
  ],
  headers_color: :cyan,
  headers_effects: [:bold],
  rows_2_color: [:white, :yellow, :white],
  table_border: :rounded,
  table_align: :center
)
```

**Box**:

```elixir
Alaja.Components.Box.print("Hello, world!", title: "Greeting", border: :rounded)
# ╭─ Greeting ──────╮
# │ Hello, world!   │
# ╰─────────────────╯
```

**Bar**:

```elixir
Alaja.Components.Bar.print(75, 100, label: "Upload", width: 40)
Alaja.Components.Bar.print(60, 100, filled_color: {72, 187, 120}, empty_color: {40, 40, 40})
```

**AnimatedBar** (8 styles):

```elixir
{:ok, pid} = Alaja.Components.AnimatedBar.start_link(animation: "moon", length: 30)

# Styles: spinner, kitt, dots, bar, moon, clock, pulse, pulsing_bar
```

**Breadcrumbs**:

```elixir
Alaja.Components.Breadcrumbs.print(["Home", "Projects", "Zaguan"])
# Home › Projects › Zaguan
```

**JSON**:

```elixir
Alaja.Components.Json.print(%{name: "Alaja", version: "2.0.0", deps: ["pote", "jason"]})
```

**ColorWheel**:

```elixir
Alaja.Components.ColorWheel.show_color_info({255, 87, 51})
Alaja.Components.ColorWheel.show_harmony_ring({255, 0, 0}, :triad)
Alaja.Components.ColorWheel.show_swatches([{255, 0, 0}, {0, 255, 0}, {0, 0, 255}])
```

Available harmonies: `triad`, `complementary`, `analogous`, `square`,
`monochromatic`, `compound`, `split-complementary`.

**Image rendering** — Kitty, iTerm2, Sixel, or ASCII fallback:

```elixir
Alaja.ImageRenderer.render_file("logo.png", width: 40, height: 20)
protocol = Alaja.ImageRenderer.detect_protocol()
```

### Raw mode

Print at exact terminal positions:

```elixir
Alaja.Printer.print("Header", raw: true, x: 0, y: 0, color: :cyan, effects: [:bold])
Alaja.Printer.print("Body text", raw: true, x: 0, y: 2)

# Globally via the command line
# mycli status --raw --pos-x 10 --pos-y 5
```

### Gradients

```elixir
Alaja.Helpers.progress_bar(75, 20, {80, 140, 255}, {200, 100, 255})
Alaja.Helpers.lerp({255, 0, 0}, {0, 0, 255}, 0.5)  # => {127, 0, 127}

Alaja.Components.ColorWheel.show_gradient(["#FF0000", "#00FF00", "#0000FF"])
```

### Syntax highlighting

```elixir
# Highlight a file (auto-detects language)
cells = Alaja.Syntax.highlight_file("lib/my_app.ex")

# Highlight content directly (returns iodata)
iodata = Alaja.Syntax.highlight_content(code, :elixir)

# Buffer-first entry point (v2.0.0+) — returns Alaja.Buffer.t/0
buf = Alaja.Syntax.highlight_buffer(code, :elixir)
Alaja.Printer.print_raw(buf)

# Tokenize a line
tokens = Alaja.Syntax.tokenize("defmodule Foo do", :elixir)
```

Supported languages: `:elixir`, `:json`, `:markdown`, `:text`.

---

## Low-level Modules

| Module                | Purpose                                             |
| --------------------- | --------------------------------------------------- |
| `Alaja.ANSI`          | Pure ANSI escape generators (fg, bg, cursor, mouse) |
| `Alaja.Terminal`      | Terminal size detection (`{cols, rows}`)            |
| `Alaja.Buffer`        | 2D cell grid with flat tuple, O(1) access           |
| `Alaja.Cell`          | Atomic unit: char + fg/bg RGB + effects list        |
| `Alaja.Helpers`       | Sparklines, progress bars, boxes, color lerp        |
| `Alaja.Syntax`        | Syntax highlighting for Elixir, JSON, Markdown      |
| `Alaja.ImageRenderer` | Terminal image rendering (Kitty/iTerm2/Sixel/ASCII) |
| `Alaja.ImageTerminal` | Image protocol detection                            |

**ANSI escapes**:

```elixir
Alaja.ANSI.fg(0, 180, 216)           # true-color foreground
Alaja.ANSI.bg(40, 44, 52)            # true-color background
Alaja.ANSI.move_to(10, 5)            # cursor to (col, row)
Alaja.ANSI.hide_cursor()
Alaja.ANSI.alt_screen_on()           # alternate buffer
Alaja.ANSI.mouse_on()                # SGR mouse tracking
```

**Buffer + Cell engine**:

```elixir
buffer = Alaja.Buffer.new(80, 24)
buffer = Alaja.Buffer.put(buffer, 10, 5, "X", {255, 0, 0})
cell = Alaja.Buffer.get(buffer, 10, 5)
Alaja.Buffer.write(buffer)  # flush to stdout
```

**Helpers**:

```elixir
Alaja.Helpers.braille_spark([10, 50, 90, 30, 70], 5)
Alaja.Helpers.box(1, 1, 40, 10, "Workers", {100, 140, 200})
Alaja.Helpers.double_box(1, 1, 40, 10, "Stats", {180, 130, 80})
```

---

## Configuration

```elixir
# Key-value store backed by Application env
Alaja.Config.get(:color_depth)           # => :truecolor
Alaja.Config.set(:color_depth, :xterm256)
Alaja.Config.all()                       # all current values

# Theme management
Alaja.Config.list_themes()               # => ["default", "dracula", "monokai", ...]
{:ok, data} = Alaja.Config.load_theme("dracula")

# Built-in themes: default, dracula, monokai, nord, light

# Path-based loader (v2.0.0+). Honours ALAJA_* env vars on top of the
# on-disk JSON file. Pass skip_env: true in tests for deterministic
# file-only behaviour.
:ok = Alaja.Config.load!("/path/to/alaja.conf")
```

### `ALAJAX_*` env vars (v2.0.0+)

Env vars win over the on-disk file, so CI shells and one-off scripts
can override the persisted config without rewriting the JSON file:

  `ALAJAX_COLOR_DEPTH`     overrides `:color_depth`    (truecolor|xterm256|ansi16)
  `ALAJAX_THEME_ACTIVE`    overrides `:theme_active`   (string)

Configurable keys: `color_depth`, `theme_active`, `refresh_rate`,
`double_buffer`, `max_workers`, `default_policy`.

### `Alaja.Theme` — the theme facade

The theme system is generated by `use Pote.Theme`, which produces a
complete facade module exposing the full Pote.Theme contract. Themes
are JSON files under `~/.config/alaja/themes` by default; override
the directory with the `ALAJA_THEMES_PATH` environment variable.

```elixir
Alaja.Theme.list()              # => ["default", "dracula", ...]
Alaja.Theme.activate("dracula")
Alaja.Theme.color("primary")    # => {189, 147, 249}
Alaja.Theme.colors()            # => %{"primary" => {189, 147, 249}, ...}

# Install a built-in palette to disk
Alaja.Theme.install_template("monokai")

# All five templates ship in the box:
# default, dracula, monokai, nord, light
```

`Alaja.Theme.register_with_pote/0` is called automatically at boot
(via `Alaja.Application.start/2`), which puts the theme resolver onto
Pote's resolver stack. After that, `Pote.parse("theme:primary")` (and
any other `"theme:<key>"` string) consults the active Alaja theme
instead of Pote's hardcoded `@default_colors` palette. Multiple apps
can register their own resolver on the same stack — Alaja composes
cleanly with Flotilla, Delfos, and any other `use Pote.Theme` consumer.

---

## Dependencies

| Package   | Purpose                                                 |
| --------- | ------------------------------------------------------- |
| **Pote**  | Colour management, theme resolution, format conversions |
| **Jason** | JSON serialization                                      |

Dev/tooling:

| Package     | Purpose                  |
| ----------- | ------------------------ |
| Credo       | Code linting             |
| Dialyxir    | Static type analysis     |
| ExDoc       | Documentation generation |
| ExCoveralls | Test coverage            |
| Batamanta   | Release packaging        |
| Benchee     | Benchmarking             |

---

## Cell/Buffer engine (v0.3.0+)

Components return `Alaja.Buffer.t()` (a 2D grid of `Alaja.Cell.t()`) from
their `render/N` function instead of opaque iodata. This unlocks
**composition** — overlays, horizontal/vertical stacking, cropping, padding —
all without re-implementing each component.

```elixir
buf1 = Components.Header.render("Status", color: :cyan)
buf2 = Components.Bar.render(width: 30, percent: 75, color: :green)

# Overlay buf2 in the bottom-right corner of buf1
combined = Buffer.overlay(buf1, buf2,
  offset_x: 5,
  offset_y: Buffer.height(buf1) - Buffer.height(buf2) - 1
)

# Print with cursor positioning (no escape coalescing required)
Printer.print_buffer(combined)
```

Available composition primitives in `Alaja.Buffer`:

- `to_iodata/1` — coalesces consecutive cells with the same ANSI state into
  a single escape prefix + chars (like any terminal emulator). Critical for
  visual parity with pre-v0.3.0 output.
- `overlay/4` — place one buffer on top of another at `(offset_x, offset_y)`.
- `hstack/2` — horizontally concatenate buffers (top edges aligned).
- `vstack/2` — vertically concatenate buffers (left edges aligned).
- `crop/5` — extract a sub-rectangle.
- `pad/3` — add padding (top/right/bottom/left, fg, bg).
- `with_offset/3` — translate a buffer by (dx, dy).

Components moved to Cell engine in v0.3.0:

| Component | Function | Returns |
|-----------|----------|---------|
| Separator | `Components.Separator.render/2` | `Buffer.t()` |
| Bar | `Components.Bar.render/2` | `Buffer.t()` |
| Breadcrumbs | `Components.Breadcrumbs.render/2` | `Buffer.t()` |
| Header | `Components.Header.render/2` | `Buffer.t()` |
| Box | `Components.Box.render/2` | `Buffer.t()` |
| Json | `Components.Json.render/2` | `Buffer.t()` |
| Table | `Components.Table.render_buffer/2` | `Buffer.t()` |
| Pulsar | (already Cell-based) | `Buffer.t()` |

The legacy `Components.Table.render/2` keeps iodata output for backwards
compatibility with downstream callers.

## Installation

Add `alaja` and `pote` to your `mix.exs`:

```elixir
def deps do
  [
    {:alaja, "~> 2.0"},
    {:pote, github: "Lorenzo-SF/pote", branch: "main"}
  ]
end
```

Then run `mix deps.get`.

---

> ## A note on history
>
> The git history of this repository was reset as part of a deliberate
> cleanup effort. The commits you can read here describe the codebase as
> it stands today — they do not preserve the original chronology of
> development.
>
> Anything worth keeping from before the reset was carried forward as
> tagged releases with explicit `CHANGELOG.md` entries. Anything not
> preserved is, by the maintainer's choice, no longer part of the
> canonical development line.

A Spanish version of this README is available at [`docs/README.es.md`](./docs/README.es.md).

## License

MIT — see [LICENSE](https://github.com/lorenzo-sf/alaja) for details.
