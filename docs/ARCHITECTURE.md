# Alaja — Architectural Reference

> Declarative CLI framework and terminal rendering kit for Elixir — v2.4.0

---

## 1. What is Alaja

Alaja is the **UI/TUI framework** of the Lorenzo-SF ecosystem. It provides
a declarative CLI DSL (`use Alaja.CLI.Definition`), a rich set of terminal
rendering components (tables, boxes, headers, bars, progress indicators,
sparklines, gradients, images), syntax highlighting for 80+ languages,
interactive prompts, and a comprehensive ANSI rendering engine built on a
2D buffer/cell architecture.

Alaja is **self-hosted** — its own escript binary uses its own DSL and
components.

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    Alaja (Facade)                             │
│  lib/alaja.ex — print, buffer, run, helpers                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │               Rendering Core                          │    │
│  │                                                      │    │
│  │  ┌────────┐  ┌──────────┐  ┌────────┐  ┌────────┐  │    │
│  │  │ Buffer │  │   Cell   │  │  ANSI  │  │Helpers │  │    │
│  │  │        │  │          │  │        │  │        │  │    │
│  │  │ 2D grid│  │ char+fg  │  │ escapes│  │braille │  │    │
│  │  │ O(1)   │  │ +bg+eff  │  │ true   │  │spark   │  │    │
│  │  │ merge  │  │ CJK-aware│  │ color  │  │box draw│  │    │
│  │  │ vstack │  │          │  │ cursor │  │lerp    │  │    │
│  │  └────────┘  └──────────┘  └────────┘  └────────┘  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │                 Components (13)                       │    │
│  │                                                      │    │
│  │  Table  Box  Header  Separator  Bar  AnimatedBar    │    │
│  │  MultiBar  Progress  Pulsar  Breadcrumbs  ColorWheel │    │
│  │  JSON  Message                                        │    │
│  │  All produce Buffer.t() → ANSI via to_iodata         │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              Syntax Highlighting                      │    │
│  │                                                      │    │
│  │  Built-in: Elixir, JSON, Markdown, text              │    │
│  │  Registered: 80+ languages via :persistent_term      │    │
│  │  Engine: tokenizer + theme resolver + renderer       │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              CLI Framework                            │    │
│  │                                                      │    │
│  │  DSL: use Alaja.CLI.Definition                       │    │
│  │  command/3, flag/3, argument/3 macros                │    │
│  │  Auto dispatch, help gen, arg parsing                │    │
│  │  30+ subcommands in self-hosted CLI                  │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              I/O Layer                                │    │
│  │                                                      │    │
│  │  Printer: types messages, raw positioning            │    │
│  │  Basics: 12 severity levels (success/error/warn...)  │    │
│  │  Interactive: question, options, yesno, menu         │    │
│  │  Image: Kitty, iTerm2, Sixel, ASCII fallback         │    │
│  │  Terminal: size detection, protocol detection        │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐    │
│  │              Theme System                             │    │
│  │                                                      │    │
│  │  Alaja.Theme (via Pote.Theme)                        │    │
│  │  Config: ~/.config/alaja/alaja.conf (JSON)           │    │
│  │  Env overrides: ALAJAX_*                             │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

---

## 3. Subsystems

### 3.1 Rendering Core
- **Buffer** (`Alaja.Buffer`): 2D grid of cells. Flat tuple-based for O(1) access.
  `put`, `get`, `fill`, `merge`, `overlay`, `crop`, `pad`, `hstack`, `vstack`,
  `with_offset`, `to_iodata` (ANSI-coalesced row renderer).
- **Cell** (`Alaja.Cell`): Single terminal cell with optional fg/bg RGB and effects.
  `to_ansi`, `merge`, `apply_effect`, `visual_width` (CJK-aware).
- **ANSI** (`Alaja.ANSI`): Pure escape code generators — hide/show cursor, clear,
  move, fg/bg true-color, bold, italic, alt screen, mouse tracking.
- **Helpers** (`Alaja.Helpers`): Braille sparklines, progress bars, box drawing,
  color interpolation, safe string-to-atom.

### 3.2 Components (13 total)
All components produce `Buffer.t()` via a `render_X(...)` function:
| Component | Purpose |
|-----------|---------|
| Table | Advanced table with borders, per-cell styling, alignment |
| Box | Border container (single/double/rounded/custom) |
| Header | Centered title with optional subtitle (small/medium/large) |
| Separator | Horizontal divider with optional centered text |
| Bar | Static progress bar with label and gradient |
| AnimatedBar | Multi-frame ANSI animation with gradient transitions |
| MultiBar | Multi-task parallel progress tracker |
| Progress | In-process single bar (no GenServer) |
| Pulsar | Pulsar/radar animation with gradient wave |
| Breadcrumbs | Navigation path display |
| ColorWheel | Color spectrum visualization |
| JSON | Pretty-printer with syntax highlighting |
| Message | Formatted message box |

### 3.3 Syntax Highlighting
- **Built-in tokenizers**: Elixir, JSON, Markdown, plain text
- **Registered languages**: 80+ via `:persistent_term` (Python, TS, Rust, Go, etc.)
- **Engine**: generic keyword/string/comment/number detection
- **Renderer**: produces `{color, text}` tuples or ANSI escapes
- **Theme resolution**: maps token types to colors via language color map with fallback chains

### 3.4 CLI Framework
- **DSL**: `use Alaja.CLI.Definition, otp_app: :my_app`
  - `command/3`, `subcommand/3`, `flag/3`, `argument/3` macros
  - Compile-time command map, runtime dispatch
  - Auto-generated `main/1` entry point
  - `halt_on_error` option for escript vs library mode
- **Dispatch**: Maps command strings to handler modules
- **Help**: Full CLI reference using Alaja's own components (self-documenting)
- **Options Parser**: Type casting for string/integer/float/boolean/atom/path/url/color_list

### 3.5 I/O Layer
- **Printer**: Central dispatcher — supports raw positioning, box wrapping,
  alignment, padding, verbose mode
- **Basics**: 12 severity functions (success/error/warning/info/debug/
  notice/alert/critical/emergency/happy/sad) with Unicode icons and
  Pote-resolved theme colors
- **Interactive**: `question` (text), `question_with_options` (menu),
  `yesno` (Y/N), `menu` (bullet list)
- **Image Renderer**: Kitty Graphics Protocol, iTerm2 inline, Sixel
  (via Trebejo.Image), ASCII fallback (via img2txt), pure Elixir ASCII art
  from PNG pixel data
- **Terminal Detection**: Kitty, iTerm2, WezTerm, Ghostty, Alacritty,
  Konsole, Foot, VS Code → maps to protocol

### 3.6 Configuration
- `~/.config/alaja/alaja.conf` (JSON)
- `ALAJAX_*` env var overrides
- Theme management via `Alaja.Theme` (bridges to Pote resolver stack)
- Keys: `:color_depth`, `:theme_active`

---

## 4. Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| **Pote** | path: ../pote | Color management, theme resolution, ANSI conversion |
| Jason | ~> 1.4 | JSON encoding/decoding for config |

Alaja's only Lorenzo-SF dependency is **Pote** (colors + themes).
Trebejo is optional (for Sixel/ASCII image rendering).

---

## 5. Consumed by

| Project | What it uses |
|---------|--------------|
| **Arrea** | `Alaja.CLI.Definition` DSL, `Alaja.Components.*`, `Alaja.Printer`, `Alaja.ANSI` |
| **Delfos** | `Alaja.CLI.Definition` DSL, all 13 components, syntax highlighting, Printer, interactive prompts |
| **Alaja itself** | (self-hosted — escript uses its own DSL and components) |
| Any Lorenzo-SF app | CLI framework via `use Alaja.CLI.Definition` |

---

## 6. Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Buffer/Cell architecture** | Terminal as a 2D grid. Composition via `hstack`/`vstack`/`merge`. Pure data, no side effects until `to_iodata`. |
| **All components return Buffer.t()** | Components are composable: nest a Table inside a Box inside a Header. No rendering happens until `Alaja.Buffer.to_iodata/1`. |
| **Self-hosted CLI** | `alaja` escript uses its own DSL. Dogfooding ensures the API is usable. |
| **Pote theme bridge** | Theme resolution via Pote's resolver stack. Host apps get `use Pote.Theme` for free. |
| **Syntax via :persistent_term** | Languages registered once at app boot, zero-cost lookups at render time. |
| **Image rendering fallback chain** | Kitty → iTerm2 → Sixel → ASCII — highest quality available for the terminal. |
| **Interactive as pure components** | `question_with_options` renders a Buffer, then reads input. Same component model, no separate path. |

---

## 7. Component Composition Pattern

```elixir
# All components follow the same pattern:
buf =
  Alaja.Components.Header.render("Delfos", subtitle: "v2.5.0")
  |> Alaja.Components.Box.render(title: "Project Status")
  |> Alaja.Components.Table.render(headers: ["Name", "Value"], rows: [...])

IO.puts(Alaja.Buffer.to_iodata(buf))
```

---

## 8. Current State (v2.4.0 — Jul 2026)

- 50+ source modules across 6 subsystems
- 40+ test files with snapshot regression testing
- 13 of 13 Alaja components in active use (by Delfos)
- All components used across the ecosystem
