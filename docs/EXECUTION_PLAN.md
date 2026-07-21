# Alaja v2.4.0 — Plan de Ejecución

> **Última actualización**: 2026-07-21
> **Auditoría original**: `AUDIT.md` (2026-07-19)
> **Auditoría complementaria**: revisión tras batch de calidad (2026-07-21)
> **Estado**: 5/5 comandos pasan. Pendientes: refactors estructurales gordos + cobertura.

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
| **Refactors estructurales** | — | — | 5 |
| **Coverage gaps** | — | — | 3 |
| **Total tareas** | **15 + 8** | **6** | **17** |

**Esfuerzo restante estimado**: ~30h (incluye refactors gordos).

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

### ALA-06: Refactor `Printer`
- **Severidad**: 🟡 P2
- **Estado**: pendiente
- **Riesgo**: arrea y delfos consumen `Alaja.Printer`

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
  2. **Fase 2: Extraer Renderer** (4h)
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
  2. **Fase 2: Extraer Range + Position** (3h)
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

## 6. Dependencias externas

| Tarea | Dependencia externa |
|-------|---------------------|
| ALA-02 | Pote: regenerar snapshots si Pote cambia defaults |
| ALA-06 | arrea, delfos consumen `Alaja.Printer` |
| ALA-16 | arrea, botica, mavis (consumers de tabla) |
| ALA-17 | arrea, mavis, cualquier render de output |

Alaja **no depende de arrea** ni de otros proyectos lorenzo-sf para compilar.

---

## 7. Riesgos globales

1. **ALA-16 Table split**: el más arriesgado. Render crítico, muchos consumers. Branch dedicada + diff exhaustivo.
2. **ALA-17 Buffer split**: core de rendering. Similar riesgo.
3. **Snapshot drift**: regenerar snapshots sin revisar diff puede ocultar bugs visuales.
4. **Consumer impact**: arrea y delfos usan `Alaja.Printer`. Cualquier cambio en rendering rompe el output de esos proyectos.

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

### Added
- Tests para show commands (ALA-21)
- Tests para `cli/parser.ex` y `cli/commands/base.ex` (ALA-22, ALA-23)

### Fixed
- Tareas ALA-XX según se completen

NO bumpear versión.