# Alaja — Document Index

> v2.4.0 — Declarative CLI framework and terminal rendering kit for Elixir

| Document | Description |
|----------|-------------|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Complete design reference: subsystems (Rendering Core, 13 Components, Syntax Highlighting, CLI DSL, I/O Layer, Theme System), dependencies, key decisions |
| [`AUDIT.md`](./AUDIT.md) | Code quality audit: snapshot theme-drift, terminal capability detection, dead Config module, oversized Printer, top 5 fixes |
| [`README.md`](../README.md) | English README — installation, usage, component overview |
| [`docs/README_ES.md`](./README_ES.md) | Spanish README |
| [`CHANGELOG.md`](../CHANGELOG.md) | Version history and release notes |
| [`LICENSE.md`](../LICENSE.md) | MIT License |
| [`plan_alaja.md`](../docs/plan_alaja.md) | Historical refactoring plan (Show→Base consolidation) |

### Ecosystem context

Alaja is the **UI/TUI layer** of the Lorenzo-SF ecosystem. It depends on
Pote (colors + themes). It is consumed by Arrea (CLI framework), Delfos
(all components), and any app using the CLI DSL. See the
[dependency graph](../docs/ARCHITECTURE.md#5-consumed-by).
