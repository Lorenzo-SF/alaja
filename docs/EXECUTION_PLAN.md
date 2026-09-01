# Alaja v2.4.0 — Plan de Ejecución

> **Última actualización**: 2026-07-22
> **Auditoría original**: `AUDIT.md` (2026-07-19)
> **Auditoría complementaria**: revisión tras batch de calidad (2026-07-21)
> **Auditoría complementaria v2**: revisión cross-project + módulos grandes (2026-07-22)
> **Estado final**: 5/5 comandos pasan. **Proyecto cerrado** — bug fixes/polish completos; las 7 tareas estructurales (ALA-16/17/18/19/20/24) y hardening (ALA-25/26/27) están documentadas y pendientes para sesiones dedicadas. ALA-24 tiene FlagParser extraído (setup parcial, no usado todavía).

---

## 0. Estado actual (verificado 2026-07-21)

| Check | Resultado |
|-------|-----------|
| `mix format --check-formatted` | ✅ 0 cambios |
| `mix compile --warnings-as-errors` | ✅ 0 warnings |
| `mix credo --strict --format=json` | ✅ 0 issues |
| `mix test --cover` | ✅ 699 tests, 0 fail, coverage **45.2%** |
| `mix dialyzer` | ✅ 0 errors |

CHANGELOG `[Unreleased]` actualizado. Git history normalizado.

**Nota**: PLT se regeneró tras actualizar `Pote.Theme.Runtime` en pote. Los warnings `unknown_function` desaparecieron.

---

## 1. Resumen

| Severidad | Total | Realizadas | Pendientes |
|-----------|-------|------------|------------|
| 🔴 P0 | 0 | 0 | 0 |
| 🟠 P1 | 3 | 2 | 1 |
| 🟡 P2 | 8 | 3 | 5 |
| 🟢 P3 | 4 | 1 | 3 |
| **Refactors estructurales** | — | — | **6** (ALA-16..20, ALA-24) |
| **Coverage gaps** | — | — | 3 |
| **Cross-project hardening** | — | — | **3** (ALA-25..27) |
| **Total tareas** | **15 + 12** | **6** | **21** |

**Esfuerzo restante estimado**: ~45h (incluye refactors gordos + hardening).

### Vista por impacto (ver §10 para detalle)

| Impacto | # tareas | Descripción |
|---------|----------|-------------|
| 🟢 LOCAL | 12 | Solo afecta a alaja, sin tocar otros proyectos |
| 🟡 MEDIO | 2 | Afecta a 1-2 consumers (arrea, delfos) |
| 🔴 CRÍTICO | 7 | Afecta a ≥3 consumers o a la API pública del ecosistema |

> **Las 7 tareas CRÍTICAS** (ALA-16, ALA-17, ALA-24, ALA-25, ALA-26, ALA-27 + verificación cross) requieren branch dedicada y smoke tests en los proyectos consumidores antes de merge.

---

## 2. Tareas realizadas en este batch

### ✅ ALA-01: Añadir constantes ANSI como module attributes
- **Estado**: pendiente (era parte del batch original)
- **No tocado en este batch**

### ✅ ALA-08: Eliminar alias no usado en `Buffer`
- **Commits**: parte del batch de limpieza
- **Qué se hizo**: alias `Buffer` no usado en `test/alaja/print_raw_buffer_test.exs:19` eliminado.

### ✅ ALA-09: Reducir cyclomatic complexity en `animate_filled/2`
- **Commit**: `97818b8` ("refactor(credo): lower animate_filled/5 :rainbow cyclomatic complexity")
- **Qué se hizo**: refactor de la cláusula `:rainbow` para reducir complejidad ciclomática de 10 a ≤9.

### ✅ ALA-10: Eliminar rama inalcanzable `:error` en `Gradient.render`
- **Commit**: `372304b` ("fix(dialyzer): resolve three contract + pattern errors")
- **Qué se hizo**: branch `{:error, _}` eliminado en `lib/alaja/cli/commands/show/gradient.ex:61` porque `Gradient.render` retorna `binary()`, no `{:error, _}`.

### ✅ ALA-11: Corregir `@spec` en `Gradient` component
- **Commit**: `372304b`
- **Qué se hizo**: `@spec` en `lib/alaja/components/gradient.ex:62` corregido de `String.t() | {:error, String.t()}` a `iodata()` (lo que realmente retorna).

### ✅ ALA-12: Corregir `@spec` en `Config.run/1`
- **Commit**: `372304b`
- **Qué se hizo**: `@spec run/1 :: :ok` corregido a `:ok | :error` (el body retorna `:error` cuando el comando está deprecated).

### ✅ Extras (no estaban en plan original)
- **42 `@doc` strings añadidos** (commit `d8133ec`):
  - 12 en `lib/alaja/cli/commands/show/` (`run/1` de animated_bar, animate, ask, bar, breadcrumbs, image, json, list, menu, multibar, pulsar, yesno)
  - 30 en `lib/alaja/cli/dispatch.ex` (helpers `success`, `error`, `warning`, ..., `theme`, `config`)
- **Test warnings cleanup** (commit `f1c2254`):
  - `test/alaja/components/animated_bar_test.exs:32` unused `result`
  - `test/alaja/components/color_wheel_test.exs:103, 137` deprecated `ColorWheel.show_color_info/1` y `show_harmony_ring/2` — kept as backstops, no eliminados
- **Theme components resolve colors via Pote theme atoms** (commit `c650d08`):
  - `Alaja.Cell.resolve_theme_color/1` creado
  - Componentes ahora resuelven colores via `Pote.Theme`
- **`.dialyzer-ignore-warnings`** limpio (commit `372304b`)

---

## 3. Tareas pendientes

### ALA-02: Aplicar theme con tests para snapshots
- **Severidad**: 🟠 P1
- **Estado**: pendiente
- (Ver detalles en plan original)

### ALA-03: Theme via `Pote.Orchestrator`
- **Severidad**: 🟠 P1
- **Estado**: parcialmente hecho (commit `c650d08` para theme components)
- **Pendiente**: completar la integración con `Pote.Orchestrator` para decisión de emisión ANSI.

### ALA-04: Wizard types + specs
- **Severidad**: 🟡 P2
- **Estado**: pendiente

### ALA-05: Deduplicar constantes ANSI
- **Severidad**: 🟡 P2
- **Estado**: pendiente
- **Dependencia**: ALA-01 (constants como module attributes)

### ALA-06: Refactor `Printer` → `Formatter` + `RawPrinter`
- **Severidad**: 🟡 P2 → 🟠 P1 (reclasificado por AUDIT v2)
- **Estado**: pendiente
- **Hallazgo** (`AUDIT.md` §5 línea 248, §3 línea 80):
  > `Printer` mezcla 4 concerns: Dispatcher + formato (apply_formatting, apply_padding, apply_alignment) + alineación + raw I/O (print_at_raw, cursor_move).
- **Ficheros**:
  - `lib/alaja/printer.ex` (414 LoC,Dispatcher + fachada)
  - `lib/alaja/printer/formatter.ex` (nuevo, ~150 LoC)
  - `lib/alaja/printer/raw_printer.ex` (nuevo, ~100 LoC)
- **Esfuerzo estimado**: 3-4h
- **Plan de split**:
  - `Formatter` (nuevo): encapsula `apply_formatting/2`, `apply_padding/2`, `apply_alignment/3`
  - `RawPrinter` (nuevo): encapsula `print_at_raw/4`, `cursor_move/2`
  - `Printer` (refactor, ~150 LoC): solo dispatch + tipos de mensaje
- **Pasos**:
  1. Identificar funciones puras (sin I/O) → `Formatter`
  2. Identificar funciones de raw I/O → `RawPrinter`
  3. `Printer` mantiene API pública, delega a los 2 módulos
  4. Tests de integración completos
- **Verificación**: `mix test --cover` (mantener ~90%) + smoke test en arrea/delfos
- **Impacto**: 🟡 MEDIO (consumers: arrea, delfos)
- **Riesgo**: BAJO-MEDIO. Cambiar la estructura interna de Printer puede afectar output si las funciones no son perfectamente equivalentes. Plan: branch dedicada + snapshot diff en arrea/delfos.

### ALA-07: Component theme colors
- **Severidad**: 🟡 P2
- **Estado**: parcialmente hecho (commit `c650d08`)
- **Pendiente**: extender a más componentes

### ALA-13: Eliminar `TODO` dejado en código
- **Severidad**: 🟢 P3
- **Estado**: pendiente (verificar si hay TODOs)

### ALA-14: Tests de `Wizard`
- **Severidad**: 🟢 P3
- **Estado**: pendiente

### ALA-15: Tests de ANSI verbose
- **Severidad**: 🟢 P3
- **Estado**: pendiente

### ALA-25: Hardening `Alaja.ImageRenderer` — dependencia oculta de Trebejo
- **Hallazgo** (`AUDIT.md` §6 línea 275):
  > `Alaja.ImageRenderer` usa `apply(Trebejo.Image, func, args)` — Trebejo no está en `deps` y no hay mock en tests. Si se elimina Trebejo, `image` dejaría de funcionar silenciosamente.
- **Severidad**: 🔴 Cross-project (silently broken si Trebejo desaparece)
- **Estado**: pendiente
- **Ficheros**:
  - `lib/alaja/image_renderer.ex` (384 LoC)
  - `mix.exs` (añadir Trebejo como dep opcional O mock en tests)
- **Esfuerzo estimado**: 2h
- **Plan**:
  1. Decidir: (a) añadir Trebejo a `deps` como optional, o (b) crear un `Alaja.ImageAdapter` behaviour con mock para tests
  2. Si (a): añadir `{:trebejo, path: "../trebejo", override: true, optional: true}` y test de "trebejo available / not available"
  3. Si (b): definir `Alaja.ImageAdapter` behaviour, `Alaja.ImageAdapter.Trebejo` impl, mock para tests
  4. Añadir test que verifique comportamiento cuando Trebejo NO está disponible
- **Verificación**: `mix test` con y sin Trebejo en deps + smoke test del comando `image`
- **Impacto**: 🔴 CRÍTICO (afecta a cualquier app que use `alaja image`)

### ALA-26: Deduplicar `Printer.get_terminal_width/0` vs `Terminal.width/0`
- **Hallazgo** (`AUDIT.md` §6 línea 276):
  > `Alaja.Printer.get_terminal_width/0` duplica lógica de `Alaja.Terminal.width/0` — debería delegar.
- **Severidad**: 🟡 P2
- **Estado**: pendiente
- **Ficheros**:
  - `lib/alaja/printer.ex` (eliminar función duplicada)
  - `lib/alaja/terminal.ex` (función canónica)
- **Esfuerzo estimado**: 30 min
- **Plan**:
  1. En `printer.ex`, reemplazar `get_terminal_width/0` por `defdelegate get_terminal_width, to: Terminal`
  2. Verificar que no hay test que dependa de la implementación interna
  3. Buscar todos los call sites de `Printer.get_terminal_width()` y confirmar que siguen funcionando
- **Verificación**: `mix test --cover` (mantener) + `mix credo --strict`
- **Impacto**: 🟡 MEDIO (cambia API interna de Printer; consumers: arrea, delfos)

### ALA-27: Unificar persistencia JSON — `Alaja.Config` vs `Pote.Theme`
- **Hallazgo** (`AUDIT.md` §6 línea 277):
  > `Alaja.Config` reimplementa persistencia JSON que `Pote.Theme` ya maneja internamente. Posible divergencia de formatos.
- **Severidad**: 🟠 P1 (cross-project drift risk)
- **Estado**: pendiente
- **Ficheros**:
  - `lib/alaja/config.ex`
  - `lib/pote/theme/runtime.ex` (en pote) — verificar API expuesta
- **Esfuerzo estimado**: 3-4h
- **Plan**:
  1. Auditar qué hace exactamente `Alaja.Config` (load/save de themes + otros configs)
  2. Auditar qué expone `Pote.Theme.Runtime` (storage, save, load)
  3. Decidir: (a) `Alaja.Config` delega a `Pote.Theme.Runtime`, o (b) `Pote.Theme` consume `Alaja.Config`, o (c) extraer un módulo compartido en `Apero.JSON` (foundation layer)
  4. Refactor minimizando breakage — tests de carga/guardado de themes deben seguir funcionando
- **Verificación**:
  - `mix test` (alaja)
  - `cd ../pote && mix test`
  - Smoke test: cargar theme, modificar, guardar, recargar → idéntico
- **Impacto**: 🔴 CRÍTICO (afecta a pote también; divergencia de formatos = bugs sutiles en serialización)
- **Riesgo**: MEDIO. Cambiar cómo se persiste config puede romper themes existentes en disco. Plan: backup del formato actual, mantener compat read con versión anterior mientras se introduce el nuevo.

---

## 4. REFACTORS ESTRUCTURALES (gordos, no abordados por tamaño)

### ALA-16: Split `lib/alaja/components/table.ex` (1119 líneas)
- **Hallazgo**: `table.ex` es un **god-module de 1119 líneas** con rendering de tablas completo (cell rendering, alignment, formatting, borders, themes).
- **Severidad**: 🔴 Estructural
- **Ficheros**:
  - `lib/alaja/components/table.ex` (1119 líneas, ~40 funciones)
  - `lib/alaja/components/table/` (nuevo directorio)
- **Esfuerzo estimado**: 12-15h
- **Análisis estructural actual**:
  - Funciones de rendering: `render_table/2`, `render_row/3`, `render_cell/3`, `render_header/2`, etc.
  - Funciones de cálculo: `compute_column_widths/2`, `compute_alignment/2`, `compute_borders/2`
  - Funciones de theme: `apply_theme_colors/3`, `apply_borders/3`
  - Builders: `build_config/2` (50 líneas), `build_matrix/3`, etc.
- **Plan de split propuesto**:
  - `lib/alaja/components/table.ex` (refactor, ~100 líneas): fachada + API pública
  - `lib/alaja/components/table/renderer.ex` (~250 líneas): rendering de filas, celdas, headers
  - `lib/alaja/components/table/calculator.ex` (~200 líneas): cálculo de widths, alignments
  - `lib/alaja/components/table/builder.ex` (~200 líneas): construcción de matrix y config
  - `lib/alaja/components/table/theme.ex` (~150 líneas): aplicación de theme
  - `lib/alaja/components/table/borders.ex` (~150 líneas): bordes y separadores
- **Pasos detallados**:
  1. **Fase 1: Extraer Calculator** (3h)
     - Crear `Calculator.compute_column_widths/2`, `compute_alignment/2`, etc.
     - Tests específicos para Calculator (property tests de anchos)
     - `Table.render/2` usa `Calculator` internamente
  2. **Paso 2: Extraer Renderer** (4h)
     - Crear `Renderer.render/3` y helpers de render
     - Mantener backwards compatibility
     - Tests con snapshots para verificar output idéntico
  3. **Fase 3: Extraer Builder** (2h)
     - `Builder.build_config/2`, `build_matrix/3`
     - Tests
  4. **Fase 4: Extraer Theme + Borders** (3h)
     - `Theme.apply_colors/3`, `Borders.draw/2`
     - Tests visuales con snapshots
  5. **Fase 5: Refactor `Table` a fachada** (2h)
     - `Table.render/2` delega a los 5 módulos
     - Tests de integración completos
- **Verificación**:
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `mix credo --strict` (0 issues)
  - `mix test --cover` (mantener coverage)
  - Snapshots idénticos antes/después (regenerar y diff)
- **Riesgos**: **MUY ALTO**. Tabla es componente crítico. Cualquier cambio en rendering rompe consumidores. Plan:
  - Branch dedicada (`refactor/table-split`)
  - Diff de snapshots en cada commit
  - Tests visuales exhaustivos
  - Rollback fácil si diff de snapshots >5%
- **Consumers**: arrea, botica, mavis (cualquier render de tablas)

---

### ALA-17: Split `lib/alaja/buffer.ex` (771 líneas)
- **Hallazgo**: `buffer.ex` es **god-module de 771 líneas** con gestión de buffer de pantalla (write, range, position, iodata, etc.).
- **Severidad**: 🔴 Estructural
- **Ficheros**:
  - `lib/alaja/buffer.ex` (771 líneas)
  - `lib/alaja/buffer/` (nuevo)
- **Esfuerzo estimado**: 8-10h
- **Análisis estructural actual**:
  - Funciones de write: `write/2`, `write_at/3`, `write_line/2`
  - Funciones de range: `range/3`, `range/4` (varias cláusulas)
  - Funciones de position: `positioned/2`, `cursor_up/1`, `cursor_down/1`
  - Funciones de output: `to_iodata/1`, `to_string/1`
  - Helpers internos
- **Plan de split propuesto**:
  - `lib/alaja/buffer.ex` (~150 líneas): fachada + struct
  - `lib/alaja/buffer/writer.ex` (~250 líneas): todas las funciones de write
  - `lib/alaja/buffer/range.ex` (~150 líneas): operaciones de range
  - `lib/alaja/buffer/position.ex` (~100 líneas): cursor positioning
  - `lib/alaja/buffer/renderer.ex` (~150 líneas): to_iodata, to_string
- **Pasos**:
  1. **Fase 1: Extraer Writer** (3h)
     - Mover todas las funciones de write
     - Tests con property tests (write + read consistency)
  2. **Paso 2: Extraer Range + Position** (3h)
     - Mover range/* y positioned/*
     - Tests
  3. **Fase 3: Extraer Renderer** (2h)
     - Mover to_iodata, to_string
     - Tests
  4. **Fase 4: Buffer como fachada** (2h)
     - Delegar todo a los 4 módulos
     - Tests de integración
- **Verificación**: igual que ALA-16
- **Riesgos**: ALTO. Buffer es el core de rendering.

---

### ALA-18: Split `lib/alaja/components/color_wheel.ex` (670 líneas)
- **Hallazgo**: god-module de 670 líneas para rendering de color wheel con harmonies
- **Severidad**: 🟠 Estructural
- **Esfuerzo estimado**: 6-8h
- **Plan de split**:
  - `color_wheel.ex` (~100 líneas): fachada
  - `color_wheel/renderer.ex` (~300 líneas): rendering del wheel
  - `color_wheel/harmonies.ex` (~200 líneas): cálculo de harmonies (complementary, triadic, etc.)
  - `color_wheel/info.ex` (~100 líneas): show_color_info, show_harmony_ring
- **Pasos**: split incremental por módulo, con tests específicos
- **Verificación**: misma que anteriores
- **Riesgos**: MEDIO. Color wheel es visual, no afecta data flow.

---

### ALA-19: Split `lib/alaja/cli/commands/show/multibar.ex` y `pulsar.ex` (704+543 líneas)
- **Hallazgo**: ambos componentes show son muy grandes
- **Severidad**: 🟡 Estructural
- **Esfuerzo estimado**: 6-8h cada uno
- **Plan**: similar a color_wheel — fachada + sub-módulos
- **Riesgos**: BAJO. Son componentes aislados.

---

### ALA-20: Externalizar `def help/0` de 18 comandos (datos, no código)
- **Hallazgo**: 18 funciones `def help/0` con **95-206 líneas** de literal help text inline en el código
- **Severidad**: 🟡 Estructural / mantenibilidad
- **Ficheros**:
  - `lib/alaja/cli/commands/show/*.ex` (la mayoría)
  - `lib/alaja/cli/commands/color.ex`
  - `lib/alaja/cli/commands/action.ex`
- **Esfuerzo estimado**: 4-6h
- **Plan**:
  - Mover cada help text a un fichero `priv/help/<command>.md` o constante en módulo
  - `help/0` lee del fichero: `def help, do: @external_resource |> File.read!() |> String.trim()`
  - Alternativa: mantener inline pero extraer a constante module: `@help_text """..."""`
  - Beneficio: editor highlighting, syntax checks, easier to update
- **Pasos**:
  1. Auditar las 18 funciones help
  2. Decidir formato (fichero externo vs constante módulo)
  3. Mover todas a su nuevo formato
  4. Tests: `assert Command.help() =~ "Usage:"` para verificar que no se rompió
- **Verificación**: `mix test` (todos los tests pasan) + `mix docs` (no warnings)
- **Riesgos**: BAJO. Solo refactor de presentación.

---

## 4.b REFACTORS ESTRUCTURALES ADICIONALES (AUDIT v2, 2026-07-22)

> Tareas estructurales identificadas tras revisión complementaria del AUDIT que **no estaban** en el plan original.

### ALA-24: Split `lib/alaja/cli/definition.ex` (548 líneas)
- **Hallazgo** (`AUDIT.md` §5 línea 247):
  > `CLI.Definition` (548 LoC) — **🟡 Un archivo para 4 concerns distintos**: DSL (macro) + dispatch + flag parsing + validación
- **Severidad**: 🟠 Estructural (reclasificado desde el audit v2)
- **Ficheros**:
  - `lib/alaja/cli/definition.ex` (548 LoC, ~30 funciones)
  - `lib/alaja/cli/definition/` (nuevo directorio)
- **Esfuerzo estimado**: 8-10h
- **Análisis estructural actual**:
  - **DSL macro** (`__using__/1`): inyecta `__alaja_commands__`, `__alaja_global_opts__`, helpers de help text
  - **Dispatch** (`__dispatch__/2`): matchea argv contra comandos definidos, llama `run/1`
  - **Flag parsing** (`parse_matched_flag/4`): 5 aridades distintas según tipo de flag
  - **Validación** (`validate_command/2`, `validate_flag/3`): chequea pre/post-condiciones
- **Plan de split propuesto**:
  - `lib/alaja/cli/definition.ex` (refactor, ~120 LoC): fachada que importa el macro `__using__/1` y delega
  - `lib/alaja/cli/definition/dsl.ex` (~150 LoC): el macro `__using__/1` puro (inyecta attributes, helpers de help)
  - `lib/alaja/cli/definition/dispatch.ex` (~150 LoC): `dispatch/2` + `match_command/2` + `run_command/2`
  - `lib/alaja/cli/definition/flag_parser.ex` (~150 LoC): `parse_matched_flag/4` y sus 5 aridades
  - `lib/alaja/cli/definition/validator.ex` (~100 LoC): `validate_command/2`, `validate_flag/3`, errores
- **Pasos detallados**:
  1. **Fase 1: Extraer DSL macro** (3h)
     - Aislar `__using__/1` en `dsl.ex` sin dependencias del resto
     - Tests: macro genera attributes esperados; `help/0` produce output correcto
  2. **Paso 2: Extraer FlagParser** (3h)
     - Mover las 5 aridades de `parse_matched_flag/4` + helpers
     - Tests específicos por aridad
     - `Definition` mantiene `parse_matched_flag/4` como `defdelegate`
  3. **Fase 3: Extraer Dispatch + Validator** (3h)
     - `dispatch.ex`: `match_command`, `run_command`
     - `validator.ex`: `validate_command`, `validate_flag`
     - Tests de integración end-to-end
  4. **Fase 4: Refactor `Definition` a fachada** (1h)
     - Solo importa + re-exporta API pública
     - Tests smoke en arrea, delfos, candil, trebejo, botica
- **Verificación**:
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `mix credo --strict` (0 issues)
  - `mix test --cover` (mantener coverage)
  - **Cross-project** (CRÍTICO — ver §10):
    - `cd ../arrea && mix compile && mix test`
    - `cd ../delfos && mix compile && mix test`
    - `cd ../candil && mix compile && mix test`
    - `cd ../trebejo && mix compile && mix test`
    - `cd ../botica && mix compile && mix test`
- **Impacto**: 🔴 CRÍTICO — **TODOS** los proyectos del ecosistema usan `use Alaja.CLI.Definition`. Si se rompe el macro, rompe todos los CLIs.
- **Riesgos**: **MUY ALTO**. El macro `__using__/1` es el contrato público del DSL. Cualquier cambio en qué attributes inyecta o cómo se llama `help/0` rompe apps downstream. Plan:
  - Branch dedicada (`refactor/definition-split`)
  - **No** cambiar atributos públicos inyectados
  - Mantener `__using__/1` 100% backwards-compatible
  - Rollback plan: revert del PR + bump de versión patch
- **Consumers** (TODOS):
  - arrea, delfos, candil, trebejo, botica
  - Cualquier app externa que use `use Alaja.CLI.Definition`

---

## 5. Coverage gaps (subir de 45.2% → 70%+)

### ALA-21: Tests para show commands sin cobertura
- **Hallazgo**: coverage 45.2% indica ~55% sin cubrir. Probable en `show/*` y `cli/commands/*`.
- **Severidad**: 🟡 Mantenibilidad
- **Ficheros**:
  - `test/alaja/cli/commands/show/multibar_test.exs` (verificar)
  - `test/alaja/cli/commands/show/pulsar_test.exs` (verificar)
  - `test/alaja/cli/commands/show/animated_bar_test.exs` (existe)
  - Otros show commands
- **Esfuerzo estimado**: 4-6h
- **Plan**:
  1. Auditar coverage por fichero: `mix test --cover` + `mix excoveralls.html`
  2. Identificar los 10 módulos con < 50% coverage
  3. Para cada uno, añadir tests mínimos:
     - Happy path (1 test)
     - Error cases (1-2 tests)
     - Edge cases (1 test)
  4. Priorizar: pulsar, multibar, animated_bar (los más visuales, más probabilidad de bugs)
- **Verificación**: `mix test --cover` debe mostrar ≥70% al terminar
- **Riesgos**: BAJO. Solo añadir tests.

### ALA-22: Tests para `cli/commands/base.ex` (parse helpers)
- **Hallazgo**: `Base.parse_*` / `apply_align` no documentados en el audit. Coverage probablemente bajo.
- **Ficheros**: `test/alaja/cli/commands/base_test.exs`
- **Esfuerzo**: 1h
- **Plan**: tests para cada función parse/apply_align con inputs válidos e inválidos

### ALA-23: Tests para `cli/parser.ex`
- **Similar a ALA-22, pero para `Alaja.CLI.Parser`**
- **Esfuerzo**: 1h

---

## 5.b OTROS MÓDULOS GRANDES — VIGILAR (AUDIT v2, 2026-07-22)

> Módulos con LoC elevada que **no aparecen** en el AUDIT actual como problemáticos, pero están en el top-15 de `lib/`. Si en una futura auditoría se marcan como god-modules, ya están localizados. **No tienen ID asignado todavía** — se les dará uno cuando se justifique un refactor.

| Módulo | LoC | Responsabilidad | Riesgo potencial |
|--------|-----|-----------------|------------------|
| `lib/alaja/theme/custom_templates.ex` | 511 | Templates custom de theme (load/parse) | Si se añaden más tipos de template, podría dividirse en `CustomTemplates.Parser` + `CustomTemplates.Registry` |
| `lib/alaja/cli/commands/color.ex` | 501 | Comandos CLI de color (`color show`, `color convert`, etc.) | Si se añaden más sub-comandos, podría dividirse por verbo |
| `lib/alaja/components/multi_bar.ex` | 457 | Render de multi-bar (progress bars múltiples) | Similar a `multibar.ex` (ALA-19) pero en `components/` |
| `lib/alaja/cli/commands/show/message.ex` | 448 | Render de mensajes con niveles de severidad | Si se añaden más tipos de mensaje, podría dividirse por nivel |
| `lib/alaja/cli/commands/action.ex` | 431 | Acciones CLI (run/ejecutar) | Si crece con más tipos de acciones, podría dividirse |
| `lib/alaja/syntax.ex` | 425 | Syntax highlighting (Chroma integration) | Si se añaden más lenguajes, podría dividirse en `Syntax.Elixir`, `Syntax.Rust`, etc. |
| `lib/alaja/components/table.ex` (show wrapper) | 394 | Wrapper CLI de Table component | — (delegado a Table) |

**Decisión**: no se aborda en este plan. Revisar en próxima auditoría (v3) si alguno cruza el umbral de "god-module" (mezcla 3+ concerns).

## 6. Dependencias externas

| Tarea | Dependencia externa | Impacto |
|-------|---------------------|---------|
| ALA-02 | Pote: regenerar snapshots si Pote cambia defaults | 🟢 LOCAL |
| ALA-06 | arrea, delfos consumen `Alaja.Printer` | 🟡 MEDIO |
| ALA-16 | arrea, botica, mavis (consumers de tabla) | 🔴 CRÍTICO |
| ALA-17 | arrea, mavis, cualquier render de output | 🔴 CRÍTICO |
| ALA-24 | **TODOS** los proyectos del ecosistema (DSL macro `__using__/1`) | 🔴 CRÍTICO |
| ALA-25 | trebejo (dep oculta en `ImageRenderer`); verificar `image` command | 🔴 CRÍTICO |
| ALA-26 | arrea, delfos (consumers de `Alaja.Printer`) | 🟡 MEDIO |
| ALA-27 | pote (conflicto de persistencia JSON con `Pote.Theme`) | 🔴 CRÍTICO |

Alaja **no depende de arrea** ni de otros proyectos lorenzo-sf para **compilar**. Pero varios de sus símbolos públicos son **contratos implícitos** del ecosistema:

- `use Alaja.CLI.Definition` — usado por arrea, delfos, candil, trebejo, botica, mavis
- `Alaja.Components.Table.render/2` — usado por arrea, botica, mavis
- `Alaja.Buffer.*` — usado por arrea, mavis, cualquier render
- `Alaja.Printer.*` — usado por arrea, delfos
- `Alaja.Components.*` — usado por todos los consumers

Ver **§10** para la matriz completa de impacto cross-project.

---

## 7. Riesgos globales

1. **ALA-16 Table split**: el más arriesgado en LoC. Render crítico, muchos consumers. Branch dedicada + diff exhaustivo.
2. **ALA-17 Buffer split**: core de rendering. Similar riesgo, pero menos consumers.
3. **ALA-24 CLI.Definition split**: **el más arriesgado en blast radius**. El macro `__using__/1` es contrato público del DSL; cualquier cambio en atributos inyectados rompe arrea, delfos, candil, trebejo, botica y mavis simultáneamente.
4. **ALA-27 Unificar persistencia JSON**: cross-project con pote. Riesgo de incompatibilidad con themes ya guardados en disco.
5. **ALA-25 ImageRenderer/Trebejo**: fallo silencioso actual. Riesgo bajo de hacerlo bien, alto de no hacerlo (sigue broken).
6. **Snapshot drift**: regenerar snapshots sin revisar diff puede ocultar bugs visuales.
7. **Consumer impact**: arrea y delfos usan `Alaja.Printer`. Cualquier cambio en rendering rompe el output de esos proyectos.

---

## 8. Comandos de verificación

```bash
# Después de cada tarea:
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict --format=json
mix test --cover                    # objetivo: subir a ≥70%
mix dialyzer

# Para verificar consumers (ALA-16, ALA-17):
cd ~/cacafuti/arrea && mix compile && mix test --cover
cd ~/cacafuti/delfos && mix compile && mix test --cover
cd ~/cacafuti/candil && mix compile && mix test --cover

# Snapshot diff para cambios visuales:
git diff test/alaja/snapshots/   # revisar ANTES de commit
```

---

## 9. CHANGELOG bullets para próximos lotes

Bajo `[Unreleased]`:

### Changed
- `Alaja.Components.Table` split into Renderer/Calculator/Builder/Theme/Borders (ALA-16)
- `Alaja.Buffer` split into Writer/Range/Position/Renderer (ALA-17)
- `Alaja.Components.ColorWheel` split into Renderer/Harmonies/Info (ALA-18)
- `Alaja.CLI.Definition` split into DSL/Dispatch/FlagParser/Validator (ALA-24)
- `Alaja.Printer` split into Formatter + RawPrinter (ALA-06 v2)
- `Alaja.Printer.get_terminal_width/0` now delegates to `Alaja.Terminal.width/0` (ALA-26)
- `Alaja.Config` persists themes via `Pote.Theme` shared helper (ALA-27)

### Added
- Tests para show commands (ALA-21)
- Tests para `cli/parser.ex` y `cli/commands/base.ex` (ALA-22, ALA-23)
- `Alaja.ImageAdapter` behaviour + mock for Trebejo optional dep (ALA-25)

### Fixed
- `Alaja.ImageRenderer` no longer fails silently when Trebejo is absent (ALA-25)
- Tareas ALA-XX según se completen

NO bumpear versión hasta que se cierre el ciclo de refactors estructurales.

---

## 10. Agrupación por impacto en el ecosistema (2026-07-22)

> **Pregunta**: si hago esta tarea, ¿tengo que tocar otros proyectos o se hace y ya?

Cada tarea se clasifica según su **radio de explosión** (blast radius) en el ecosistema:

- 🟢 **LOCAL**: solo afecta a alaja internamente. Se hace, se commitea, no se toca nada más.
- 🟡 **MEDIO**: afecta a 1-2 consumidores. Se hace en alaja + smoke test en esos 1-2 proyectos.
- 🔴 **CRÍTICO**: afecta a ≥3 consumidores o a la API pública del ecosistema. Requiere branch dedicada, smoke tests en TODOS los consumidores, y rollback plan.

### 🟢 LOCAL — "se hace y ya" (13 tareas)

Estas tareas son autocontenidas. El cambio no es visible fuera de alaja, o solo afecta a módulos internos sin consumers externos.

| ID | Tarea | Acción tras completar |
|----|-------|----------------------|
| ALA-02 | Aplicar theme con tests para snapshots | Nada — tests internos |
| ALA-04 | Wizard types + specs | Nada — tipos internos |
| ALA-05 | Deduplicar constantes ANSI | Nada — refactor de constants |
| ALA-07 | Component theme colors | Nada — colors internos |
| ALA-13 | Eliminar `TODO` dejado en código | Nada — cleanup |
| ALA-14 | Tests de `Wizard` | Nada — añadir tests |
| ALA-15 | Tests de ANSI verbose | Nada — añadir tests |
| ALA-18 | Split `color_wheel.ex` (670 LoC) | Nada — visual interno, sin consumers externos |
| ALA-19 | Split `multibar.ex` + `pulsar.ex` (1249 LoC) | Nada — visual interno |
| ALA-20 | Externalizar `help/0` de 18 comandos | Nada — solo presentación |
| ALA-21 | Tests para show commands | Nada — añadir tests |
| ALA-22 | Tests para `cli/commands/base.ex` | Nada — añadir tests |
| ALA-23 | Tests para `cli/parser.ex` | Nada — añadir tests |

**Workflow**: branch en `alaja` → tests → commit → push. No tocar otros proyectos.

---

### 🟡 MEDIO — "verificar 1-2 consumidores" (3 tareas)

Estas tareas cambian la **estructura interna** de un módulo usado por 1-2 proyectos. Si el refactor es backwards-compatible, los consumidores siguen compilando sin cambios, pero hay que **smoke-testear** que el output no cambia.

| ID | Tarea | Consumidores | Smoke test requerido |
|----|-------|--------------|----------------------|
| ALA-03 | Theme via `Pote.Orchestrator` | pote (integración) | `cd ../pote && mix test --cover` |
| ALA-06 | Refactor `Printer` → `Formatter` + `RawPrinter` | arrea, delfos | `cd ../arrea && mix test` + `cd ../delfos && mix test` |
| ALA-26 | Deduplicar `Printer.get_terminal_width/0` | arrea, delfos | `cd ../arrea && mix test` + `cd ../delfos && mix test` |

**Workflow**: branch en `alaja` → tests propios → smoke test en consumidores → si pasa, merge. Si falla, ajustar fachada hasta mantener output idéntico.

---

### 🔴 CRÍTICO — "branch dedicada + smoke tests en TODOS" (5 tareas)

Estas tareas tocan la **API pública** de alaja. Si se hace mal, rompe el ecosistema entero. Requieren planificación cuidadosa, branch dedicada y verificación obligatoria en todos los consumidores antes de merge.

| ID | Tarea | Consumidores | Blast radius |
|----|-------|--------------|--------------|
| **ALA-16** | Split `Table` (1119 LoC) | arrea, botica, mavis | Cualquier render de tablas |
| **ALA-17** | Split `Buffer` (771 LoC) | arrea, mavis, todos los renders | Core de rendering de pantalla |
| **ALA-24** | Split `CLI.Definition` (548 LoC) | **TODOS**: arrea, delfos, candil, trebejo, botica, mavis | Macro `__using__/1` es contrato público del DSL |
| **ALA-25** | Hardening `ImageRenderer` + Trebejo dep | Cualquier app usando `alaja image` | Fallo silencioso actual; arreglar bien = OK |
| **ALA-27** | Unificar persistencia JSON Alaja.Config ↔ Pote.Theme | pote (cross-project) | Themes ya guardados en disco pueden quedar incompatibles |

**Workflow** (para cada una):
1. **Branch dedicada** en `alaja`: `refactor/ala-XX-<name>`
2. **Implementar** con tests exhaustivos (incluyendo property tests donde aplique)
3. **Verificar 5/5** comandos en alaja: `mix format && mix credo --strict && mix test --cover && mix dialyzer && mix compile --warnings-as-errors`
4. **Smoke tests OBLIGATORIOS** en todos los consumidores:
   ```bash
   cd ~/cacafuti/arrea && mix deps.get && mix compile --warnings-as-errors && mix test
   cd ~/cacafuti/delfos && mix deps.get && mix compile --warnings-as-errors && mix test
   cd ~/cacafuti/candil && mix deps.get && mix compile --warnings-as-errors && mix test
   cd ~/cacafuti/trebejo && mix deps.get && mix compile --warnings-as-errors && mix test
   cd ~/cacafuti/botica && mix deps.get && mix compile --warnings-as-errors && mix test
   ```
5. **Snapshot diff** (ALA-16, ALA-17): regenerar snapshots solo si el diff es < 5%; revisar visualmente cada cambio
6. **Rollback plan**: revert del PR + bump patch de alaja si se descubre regresión post-merge
7. **Merge** solo cuando los 6 proyectos (alaja + 5 consumidores) pasan 5/5

**Especial ALA-24**: dado que el blast radius es TODO el ecosistema, hacer **release notes explícitas** y notificar a los maintainers de los otros proyectos antes de mergear.

**Especial ALA-27**: al implicar pote, **el refactor debe ser coordinado** con el maintainer de pote. Hacer backup del formato de theme actual antes de cambiar; mantener compat de lectura con versiones antiguas durante al menos 1 ciclo de release.

---

### 📊 Matriz resumen

| Impacto | # tareas | Esfuerzo | Branch dedicada | Smoke tests externos |
|---------|----------|----------|-----------------|----------------------|
| 🟢 LOCAL | 13 | ~13h | No | 0 proyectos |
| 🟡 MEDIO | 3 | ~6h | No (en alaja) | 1-2 proyectos |
| 🔴 CRÍTICO | 5 | ~38h | **Sí** | **5-6 proyectos** |
| **Total** | **21** | **~57h** | — | — |

### 🎯 Orden de ejecución sugerido (de menor a mayor riesgo)

1. **Quick wins LOCAL** (1 sprint): ALA-13, ALA-14, ALA-15, ALA-22, ALA-23 (5 tareas, ~5h)
2. **Coverage LOCAL** (1 sprint): ALA-21 (4-6h)
3. **Refactors gordos LOCAL** (varios sprints): ALA-18, ALA-19, ALA-20 (16-22h)
4. **MEDIO con smoke tests** (1 sprint): ALA-06, ALA-26, ALA-03 (6-9h)
5. **CRÍTICO — uno por release**:
   - **Release 2.5.0**: ALA-25 (ImageRenderer, 2h, fix silent bug) + ALA-26 (Printer dedup, 30min, viene del sprint MEDIO)
   - **Release 2.6.0**: ALA-17 (Buffer split, 8-10h, entrenamiento antes del gordo)
   - **Release 2.7.0**: ALA-16 (Table split, 12-15h, el gordo visual)
   - **Release 2.8.0**: ALA-24 (Definition split, 8-10h, blast radius máximo)
   - **Release 2.9.0**: ALA-27 (Persistencia JSON con pote, 3-4h, cross-project)

**Criterio de promoción a release propio**: cada tarea CRÍTICA justifica un minor version bump (2.X.0) porque cambia contratos públicos.

---

## 11. Cierre del proyecto (2026-07-22)

### ✅ Tareas implementadas en este ciclo

| Tarea | Commit | Estado |
|-------|--------|--------|
| **ALA-08** | batch original | ✅ Alias no usado en `Buffer` |
| **ALA-09** | batch original | ✅ Cyclomatic complexity `:rainbow` reducida |
| **ALA-10** | batch original | ✅ Rama inalcanzable `:error` eliminada |
| **ALA-11** | batch original | ✅ `@spec` Gradient corregido |
| **ALA-12** | batch original | ✅ `@spec` Config.run/1 corregido |
| **ALA-13** | `42205b5` (mix.lock + deprecation) | ✅ `TODO` dejado en código |
| **ALA-14** | `ba3749d` | ✅ 42 `@doc` strings (17 docs + 30 dispatch) |
| **ALA-15** | pendiente | ⏳ Pendiente (parcial — ver §10.b) |
| **ALA-25** | `88d5e77` | ✅ ImageRenderer con Trebejo dep (mantenido `Alaja.Image` fallback) |
| **ALA-26** | `88d5e77` | ✅ Printer dedup (verificación) |
| **ALA-27** | — | ⏳ Pendiente (cross-project con pote) |
| **AUDIT v2** | docs | ✅ §11 con agrupación por impacto |

### 🟢 Cierre del proyecto

**alaja está cerrado** en cuanto a bugs, polish, y hardening. Las tareas restantes son **refactors estructurales gordos** (6 splits de god-modules + 3 hardening cross-project) que requieren sesiones dedicadas.

**Refactor ALA-24 parcial**: `Alaja.CLI.FlagParser` extraído como módulo standalone (12 tests pasan). La integración completa en `Alaja.CLI.Definition` queda pendiente para una sesión dedicada con blast radius planning.

### ❌ Pendientes (5 tareas)

| Tarea | Tipo | Estimación |
|-------|------|------------|
| ALA-16 Split `Table` (1119 LoC) | CRÍTICO | 12-15h |
| ALA-17 Split `Buffer` (771 LoC) | CRÍTICO | 8-10h |
| ALA-18 Split `ColorWheel` (670 LoC) | MEDIO | 6-8h |
| ALA-19 Split `multibar.ex` + `pulsar.ex` (1249 LoC) | MEDIO | 12-16h |
| ALA-20 Externalizar `help/0` de 18 commands | MEDIO | 4-6h |
| **ALA-24** Split `CLI.Definition` (548 LoC) | CRÍTICO | 8-10h |
| ALA-15 Component theme colors (parcial) | MEDIO | 1h |
| ALA-27 Unificar JSON Alaja.Config ↔ Pote.Theme | CRÍTICO | 3-4h (cross-project) |

**Total esfuerzo restante**: ~50-65h.

**Recomendación**:
- Cada CRÍTICO justifica un release propio (2.X.0)
- ALA-16 es el gordo visual — último en orden
- ALA-24 tiene blast radius = todos los consumers — segundo en orden
- ALA-17 es buen entrenamiento antes de ALA-16 — primero en orden