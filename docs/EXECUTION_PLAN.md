# Alaja v2.4.0 — Plan de Ejecución

> Generado desde `docs/AUDIT.md` · 2026-07-19
> Total hallazgos: P0=0, P1=3, P2=8, P3=4 · Effort estimado: ~13h

---

## 1. Resumen

| Severidad | Count | Effort |
|-----------|-------|--------|
| 🔴 P0 | 0 | — |
| 🟠 P1 | 3 | 2h 30min |
| 🟡 P2 | 8 | 8h 35min |
| 🟢 P3 | 4 | 2h 10min |
| **Total** | **15** | **~13h** |

No hay P0. Los P1 (ANSI escapes, snapshots, dialyzer) son la máxima prioridad y desbloquean tareas P2/P3 posteriores.

---

## 2. Dependencias entre hallazgos

```
P1.3 (ANSI escapes) ──┬──→ P2.4 (ANSI constants dedup)
                      ├──→ P2.3 (Printer refactor)
                      ├──→ P2.8 (Component theme colors)
                      └──→ P3.4 (ANSI verbose tests)
P2.5 (Wizard types) ──→ P3.3 (Wizard tests)
```

---

## 3. Dependencias externas

| Tarea | Dependencia | Detalle |
|-------|-------------|---------|
| ALA-02 | Pote | Snapshots usan tema de Pote. Si Pote cambia defaults de nuevo, regenerar. |
| ALA-03 | Pote.Orchestrator | Delegar ANSI decision a `Pote.Orchestrator` es opcional pero recomendado. |

Alaja **no depende de arrea** ni de ningún otro proyecto Lorenzo-SF para compilar.

---

## 4. Riesgos generales

- **Regenerar snapshots** sin revisión puede ocultar regresiones visuales. Revisar diff antes de commit.
- **Printer refactor (ALA-10)** es el cambio más invasivo (~3h). Arrea y Delfos consumen `Alaja.Printer` — verificar compilación downstream.
- Si se introduce `Alaja.Config.color_enabled?/0`, migrar todos los puntos de emisión ANSI. Un punto olvidado genera comportamiento inconsistente.
- `mix credo --all` debe mantenerse en 0 violaciones tras cada tarea.

---

## 5. Fases y tareas

---

### Fase 1: Críticos (P0)

No hay hallazgos P0. Ir a Fase 2.

---

### Fase 2: Alta prioridad (P1)

#### ALA-01: Corregir pattern match imposible en Progress (Dialyzer)
- **Hallazgo**: P1.2 — Dialyzer warning en `progress.ex:116`
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/alaja/components/progress.ex`
- **Esfuerzo**: 15 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Abrir `lib/alaja/components/progress.ex` línea 116
  2. Cambiar `case :io.getopts(:standard_error) do {:ok, opts} -> ...` por `case :io.getopts(:standard_error) do opts when is_list(opts) -> Keyword.get(opts, :tty, false); _ -> false end`
  3. Ejecutar `mix dialyzer` para confirmar que el warning desaparece
- **Verificación**: `mix dialyzer --no-html` (sin nuevas warnings) + `mix test`
- **Riesgos**: Ninguno. Cambio localizado y bien entendido.

---

#### ALA-02: Regenerar o migrar snapshots drift
- **Hallazgo**: P1.1 — 2 snapshot tests fallan por cambio de tema en Pote
- **Severidad**: 🟠 P1
- **Ficheros**: `test/alaja/snapshot_test.exs`, `test/snapshots/`
- **Esfuerzo**: 15 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Pote (tema estable)
- **Pasos**:
  1. Decidir enfoque: regenerar snapshots (rápido) vs migrar a aserciones estructurales (robusto)
  2. **Opción A (regenerar)**: `UPDATE_SNAPSHOTS=1 mix test` — los ficheros `test/snapshots/*` se actualizan automáticamente
  3. **Opción B (estructural)**: Reemplazar aserciones byte-equality por regex sobre patrón ANSI. Ej: `assert output =~ ~r/\\e\[38;2;\d+;\d+;\d+m/`
  4. Verificar que `mix test` pasa con 0 fallos (los 2 previos deben desaparecer)
- **Verificación**: `mix test` (0 failures) + `mix credo --all`
- **Riesgos**: Regenerar snapshots sin revisar diff puede ocultar regresiones. Usar `git diff test/snapshots/` para revisar.

---

#### ALA-03: Implementar detección ANSI condicional en Printer
- **Hallazgo**: P1.3 — ANSI escapes emitidos sin verificar TTY
- **Severidad**: 🟠 P1
- **Ficheros**: `lib/alaja/config.ex` (o `lib/alaja/printer.ex`), `lib/alaja/printer/basics.ex`, `lib/alaja/ansi.ex`, `lib/alaja/cell.ex`, `lib/alaja/chunk_text.ex`
- **Esfuerzo**: 2h
- **Dependencias**: Ninguna
- **Dependencias externas**: Opcional: delegar a `Pote.Orchestrator`
- **Pasos**:
  1. Añadir `def color_enabled?/0` en `Alaja.Config`:
     ```elixir
     def color_enabled? do
       get(:no_color, false) == false and IO.ANSI.enabled?()
     end
     ```
  2. Modificar `Cell.build_ansi_prefix/1` para consultar `Alaja.Config.color_enabled?/0` antes de emitir escapes:
     - Si deshabilitado, devolver prefijo vacío (sin escapes)
  3. Modificar `ChunkText.render/1` para respetar el flag
  4. Modificar `Table.render_formatted/3` (o las funciones que construyen escapes en `table.ex`) para consultar el flag
  5. Modificar `Printer.print_success/1` y afines en `printer/basics.ex` para silenciar escapes si no es TTY
  6. Modificar `CLI.Help` si emite ANSI directamente
- **Verificación**: `mix test` + `mix credo --all` + `mix dialyzer`
- **Riesgos**: Alto impacto — toca 5+ módulos. Un punto olvidado emite escapes inconsistentemente. Verificar con `stdout |> file` que no aparecen escapes literales.

---

### Fase 3: Media (P2)

#### ALA-04: Extraer constantes ANSI 16-color a módulo compartido
- **Hallazgo**: P2.4 — `@ansi_standard_colors` duplicado en Table y Box
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/alaja/components/table.ex`, `lib/alaja/components/box.ex`, `lib/alaja/ansi.ex` (o `lib/alaja/cell.ex`)
- **Esfuerzo**: 30 min
- **Dependencias**: ALA-03 (preferible haber definido el enfoque ANSI primero)
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Mover `@ansi_standard_colors` de `table.ex:L429-446` y `box.ex:L32-49` a `Alaja.Ansi` (o `Alaja.Cell`)
  2. Actualizar Table y Box para referenciar la constante compartida
  3. Verificar que no hay otras copias de la misma constante (grep `@ansi_standard_colors` o `0..15` en `lib/`)
- **Verificación**: `mix test` + `mix credo --all`
- **Riesgos**: Bajo. Refactor mecánico.

---

#### ALA-05: Eliminar o redirigir comando Config muerto
- **Hallazgo**: P2.2 — Comando `config` es no-op, módulo deprecated
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/alaja/cli/commands/config.ex`, `lib/alaja/cli/dispatch.ex`
- **Esfuerzo**: 20 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Decidir: (a) eliminar mapping en dispatch.ex, (b) reemplazar por error informativo "comando eliminado, usa `theme`", o (c) eliminar archivo
  2. Opción recomendada: (b) — mantener el comando pero que emita `IO.puts(:stderr, "config is deprecated, use 'alaja theme' instead")` y retorne error
  3. Si se elimina, actualizar tests de dispatch que referencien `:config`
- **Verificación**: `mix test` + `mix credo --all`
- **Riesgos**: Bajo. Si se elimina y algún consumidor lo usa, tendrá error de dispatch.

---

#### ALA-06: Migrar llamadas a funciones deprecadas en ColorWheel
- **Hallazgo**: P2.1 — 3 funciones deprecadas con 5 usos en tests
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/alaja/components/color_wheel.ex`, `test/alaja/components/color_wheel_test.exs`
- **Esfuerzo**: 45 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Identificar reemplazos: `show_color_info/2` → `render_color_formats/2` + `render_color_variants/1`; `show_harmony_ring/3` → `render_ascii_wheel/3` + `render_swatch_list/1`; `show_swatches/2` → `render_swatch_list/1`
  2. Migrar tests en `color_wheel_test.exs` líneas 93, 100, 110, 119, 128
  3. Marcar funciones originales con `@doc deprecated` si no lo están ya, y añadir `@deprecated` si falta
  4. Verificar que ningún otro módulo las llama (grep por `show_color_info`, `show_harmony_ring`, `show_swatches` en `lib/` y `test/`)
- **Verificación**: `mix test` + `mix credo --all`
- **Riesgos**: Bajo. Las funciones nuevas existen y tienen tests.

---

#### ALA-07: Añadir @spec a Wizard.Renderers
- **Hallazgo**: P2.5 — 0 especificaciones en módulo público interno
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/alaja/wizard/renderers.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Identificar funciones públicas: `inline/1`, `compact/1`, `stacked/1`, `wizard/1`, `compact_wizard/1` y otras
  2. Añadir `@spec` para cada una. Tipo de retorno: `Alaja.Buffer.t()`
  3. Añadir `@doc` breve para cada función
- **Verificación**: `mix test` + `mix credo --all` + `mix dialyzer`
- **Riesgos**: Bajo.

---

#### ALA-08: Añadir Logger callback en ErrorHandler
- **Hallazgo**: P2.6 — I/O directo a stderr sin pasar por logging
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/alaja/cli/error_handler.ex`
- **Esfuerzo**: 45 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Añadir opción de configuración: `Alaja.Config.get(:error_handler_logger, false)`
  2. En `ErrorHandler`, antes de `IO.puts(:stderr, ...)`, verificar flag y llamar a `Logger.warning()` si activo
  3. Mantener stderr como fallback por defecto (comportamiento backward compatible)
  4. Añadir test que verifique que con flag activo se emite al Logger
- **Verificación**: `mix test` + `mix credo --all`
- **Riesgos**: Bajo. Cambio backward compatible.

---

#### ALA-09: Investigar y corregir GenServer crash en test por IO.gets
- **Hallazgo**: P2.7 — `StringIO.state_after_read/4` crash durante test suite
- **Severidad**: 🟡 P2
- **Ficheros**: `test/` (varios), `lib/alaja/interactive.ex`
- **Esfuerzo**: 1h
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Ejecutar `mix test --trace --only log:error` o buscar en el log de test el PID que crashea
  2. Identificar qué test específico invoca `Interactive` sin mockear stdin
  3. Añadir `capture_io` o mock de `IO.gets` en ese test
  4. Alternativa: en `Interactive`, añadir `rescue` alrededor de `IO.gets` para casos sin TTY
- **Verificación**: `mix test` (sin logs de crash) + `mix credo --all`
- **Riesgos**: Medio — requiere identificar el test exacto. La recomendación del audit es mockear `IO.gets`.

---

#### ALA-10: Refactorizar Printer separando formato, raw I/O y dispatcher
- **Hallazgo**: P2.3 — Printer mezcla rendering, alineación y I/O (414 líneas)
- **Severidad**: 🟡 P2
- **Ficheros**: `lib/alaja/printer.ex`, (nuevos) `lib/alaja/printer/formatter.ex`, `lib/alaja/printer/raw_printer.ex`
- **Esfuerzo**: 3h
- **Dependencias**: ALA-03 (ANSI detection debe estar resuelto para no refactorizar dos veces)
- **Dependencias externas**: Verificar que Arrea y Delfos siguen compilando — consumen `Alaja.Printer`
- **Pasos**:
  1. Crear `Alaja.Printer.Formatter` con `apply_formatting/2`, `apply_padding/2`, `apply_alignment/2`
  2. Crear `Alaja.Printer.RawPrinter` con `print_at_raw/2`, `cursor_move/1`
  3. En `Printer`, delegar a los nuevos módulos manteniendo la API pública intacta
  4. Mover lógica de box-wrapping condicional a un módulo separado o mantener en Printer como dispatcher
  5. Actualizar imports en módulos que llamen directamente a funciones movidas
- **Verificación**: `mix test` (0 failures) + `mix credo --all` + compilar arrea y delfos con `mix compile`
- **Riesgos**: **Alto** — es el cambio más grande del plan. La API pública no debe cambiar pero la interna sí. Verificar que todos los tests de Printer pasan. Posible rotura en consumidores si importan funciones internas.

---

---

#### ALA-15: Migrar defaults de 7 componentes a colores de tema vía Pote
- **Hallazgo**: P2.8 — Box, Header, Bar, Breadcrumbs, Separator, AnimatedBar, Pulsar usan RGB fijo
- **Severidad**: 🟡 P2
- **Ficheros**:
  - `lib/alaja/components/box.ex` — `@default_border_color {0,180,216}` → `:primary`
  - `lib/alaja/components/header.ex` — `@default_color {0,180,216}` → `:primary`
  - `lib/alaja/components/bar.ex` — `@default_filled_color {0,180,216}` → `:success`
  - `lib/alaja/components/breadcrumbs.ex` — `@default_item_color {0,180,216}` → `:primary`, `@default_current_color {255,255,255}` → `:text`
  - `lib/alaja/components/separator.ex` — `@default_color {64,64,64}` → `:muted`
  - `lib/alaja/components/animated_bar.ex` — colores de frames → colores de tema con gradiente
  - `lib/alaja/components/pulsar.ex` — colores de wave → `:primary` con gradiente
- **Esfuerzo**: 2h
- **Dependencias**: ALA-03 (ANSI detection resuelto), ALA-04 (constantes compartidas)
- **Dependencias externas**: Pote (resolución de colores)
- **Pasos**:
  1. En cada componente, reemplazar `@default_color {r,g,b}` por un átomo de tema (`:primary`, `:success`, `:muted`, etc.)
  2. Modificar la función que aplica el color para que, si recibe un átomo, lo resuelva vía `Cell.safe_pote_color/1` en lugar de usarlo como RGB
  3. Mantener compatibilidad hacia atrás: si el usuario pasa `{r,g,b}`, debe seguir funcionando
  4. En `AnimatedBar`, migrar los colores de cada estilo de animación a funciones que acepten el color base del tema y computen gradientes
  5. En `Pulsar`, migrar el color de la onda a `:primary` con degradado al color base
  6. Actualizar tests que verifiquen colores específicos (pueden necesitar mock del tema)
- **Verificación**:
  ```bash
  mix test                                                # 0 failures
  mix credo --all                                         # 0 violations
  mix dialyzer --no-html                                  # sin nuevas warnings
  # Verificación manual: cambiar tema y ver componentes:
  alaja theme set dracula && alaja header "Test"
  alaja theme set default && alaja header "Test"
  ```
- **Riesgos**: Medio. Cambiar defaults puede afectar a consumidores (delfos, arrea) que dependan de los colores exactos. Verificar visualmente que los nuevos colores por defecto del tema son aceptables. Los tests existentes que verifiquen valores RGB concretos fallarán — actualizarlos.

---

### Fase 4: Baja (P3)

#### ALA-11: Eliminar variables no usadas en tests
- **Hallazgo**: P3.1 — `result =`, alias `Buffer`, alias `Components` no usados
- **Severidad**: 🟢 P3
- **Ficheros**: `test/alaja/components/animated_bar_test.exs:32`, `test/alaja/print_raw_buffer_test.exs:19`, `test/alaja/components/components_test.exs:4`
- **Esfuerzo**: 10 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. En `animated_bar_test.exs:32`, cambiar `result = ...` por `_result = ...` o eliminar
  2. En `print_raw_buffer_test.exs:19`, eliminar alias `Buffer` no usado
  3. En `components_test.exs:4`, eliminar alias `Components` no usado
- **Verificación**: `mix test` + `mix credo --all`
- **Riesgos**: Ninguno.

---

#### ALA-12: Añadir variantes Buffer a Helpers y marcar legacy
- **Hallazgo**: P3.2 — `box/5` y `double_box/5` devuelven tuplas pre-Buffer
- **Severidad**: 🟢 P3
- **Ficheros**: `lib/alaja/helpers.ex`
- **Esfuerzo**: 30 min
- **Dependencias**: Ninguna
- **Dependencias externas**: Verificar que Delfos no usa la API legacy de Helpers
- **Pasos**:
  1. Añadir `box/6` (con opción `:as_buffer` o nueva función `box_to_buffer/5`) que devuelva `Buffer.t()`
  2. Marcar `box/5` y `double_box/5` actuales con `@deprecated`
  3. Añadir tests para las nuevas variantes
- **Verificación**: `mix test` + `mix credo --all`
- **Riesgos**: Bajo. Backward compatible si se mantienen las funciones legacy.

---

#### ALA-13: Añadir tests unitarios para Wizard renderers
- **Hallazgo**: P3.3 — Renderers de Wizard sin tests específicos
- **Severidad**: 🟢 P3
- **Ficheros**: (nuevo) `test/alaja/wizard_renderers_test.exs`, `lib/alaja/wizard/renderers.ex`
- **Esfuerzo**: 1h
- **Dependencias**: ALA-07 (tipos definidos facilitan escribir tests)
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Crear `test/alaja/wizard_renderers_test.exs`
  2. Para cada renderer (`inline`, `compact`, `stacked`, `wizard`, `compact_wizard`):
     - Verificar que retorna `%Alaja.Buffer{}`
     - Verificar ancho > 0 y alto > 0
     - Verificar contenido textual esperado (primer celda, última celda)
  3. Ejecutar `mix test test/alaja/wizard_renderers_test.exs`
- **Verificación**: `mix test` (nuevos tests pasan) + `mix credo --all`
- **Riesgos**: Bajo.

---

#### ALA-14: Capturar output ANSI en tests con capture_io
- **Hallazgo**: P3.4 — Tests que imprimen ANSI ensucian output de `mix test`
- **Severidad**: 🟢 P3
- **Ficheros**: Múltiples archivos de test que llaman a `print_*` o `render_*`
- **Esfuerzo**: 30 min
- **Dependencias**: ALA-03 (los módulos deben respetar el flag color_enabled)
- **Dependencias externas**: Ninguna
- **Pasos**:
  1. Identificar tests que producen output ANSI: `mix test 2>&1 | grep -E '\e\[' | head -20` muestra las fuentes
  2. Envolver llamadas a `print_*` en `capture_io(fn -> ... end)` en los tests identificados
  3. Alternativa: desactivar color en tests con `Alaja.Config.put(:no_color, true)` en `setup`
- **Verificación**: `mix test` (output limpio, sin escapes ANSI visibles)
- **Riesgos**: Bajo. No afecta lógica de negocio.

---

## 6. Orden de ejecución completo

```
Fase 2 (P1):
  ALA-01 (15min) → ALA-02 (15min) → ALA-03 (2h)
Fase 3 (P2):
  ALA-05 (20min) → ALA-06 (45min) → ALA-07 (30min) → ALA-08 (45min) → ALA-09 (1h)
  ALA-04 (30min, tras ALA-03) → ALA-10 (3h, tras ALA-03)
  ALA-15 (2h, tras ALA-03 + ALA-04)
Fase 4 (P3):
  ALA-11 (10min) → ALA-12 (30min) → ALA-13 (1h, tras ALA-07) → ALA-14 (30min, tras ALA-03)
```

**Total**: ~13h. Ejecutar en orden de fase, respetando dependencias marcadas.

---

## 7. Verificación final

```bash
# Tras completar todas las tareas:
mix test                                         # 0 failures (snapshots regenerados)
mix credo --all                                  # 0 violations
mix dialyzer --no-html                           # 0 warnings (ALA-01)
mix format --check-formatted                     # formateo correcto
mix compile --warnings-as-errors                 # sin warnings de compilación
```

**Verificación downstream** (si se modificó API pública):
```bash
(cd ../arrea && mix compile)                     # arrea compila
(cd ../delfos && mix compile)                    # delfos compila
```
