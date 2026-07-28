# Alaja v2.4.0 — Auditoría de calidad de código

> **Fecha**: 2026-07-19  
> **Alcance**: `lib/alaja/` (74 módulos, ~6.200 LOC), `test/` (39 archivos, 696 tests)  
> **Herramientas**: `mix test`, `mix credo --all`, `mix dialyzer`, inspección manual  

---

## Resumen ejecutivo

| Métrica | Valor |
|---|---|
| Tests totales | 696 |
| Fallos | 2 (snapshot theme-drift, esperados) |
| Credo violations | 0 — impecable |
| Dialyzer warnings | 1 (pattern match in `Progress`) |
| Deprecaciones activas | 3 funciones en `ColorWheel`, 1 módulo `Config`, 1 en `Pulsar` |
| Componentes sin Pote | 7 (Box, Header, Bar, Breadcrumbs, Separator, AnimatedBar, Pulsar) — ver P2.8 |
| Cobertura tipos | Excelente (~92% funciones públicas tipadas) |
| Complejidad pico | `Table` (1135 líneas), `Buffer` (771), `Definition` (548) |

---

## 1. Hallazgos por severidad

### P0 (🔴) — Debe corregirse antes del próximo release

Ninguno. El proyecto no tiene bugs de runtime conocidos, fugas de seguridad, ni pérdida de datos.

---

### P1 (🟠) — Debe corregirse en el próximo ciclo

#### P1.1 — Snapshot drift no gestionado en CI (test/snapshot_test.exs)

**Archivo**: `test/alaja/snapshot_test.exs`  
**Síntoma**: 2 tests fallan (`json_simple`, `json_nested`) porque los colores RGB en las snapshots no coinciden con los que produce el tema activo de Pote.  
**Causa raíz**: Las snapshots se generaron con una versión anterior del tema por defecto de Pote (`205,214,244` / `166,227,161` / `137,180,250`). El tema actual produce `236,239,244` / `163,190,140` / `129,161,193`. Es *theme drift* — los colores por defecto de Pote cambiaron y las snapshots no se regeneraron.  
**Impacto**: `mix test` siempre reporta 2 fallos. Cualquier CI con `--warnings-as-errors` fallaría.  
**Recomendación**: Decidir si las snapshots se regeneran (`UPDATE_SNAPSHOTS=1 mix test`) o se eliminan en favor de aserciones estructurales. Si se mantienen, documentar el procedimiento de regeneración en `ARCHITECTURE.md`.

#### P1.2 — Dialyzer warning: pattern match imposible en lib/alaja/components/progress.ex:116

**Archivo**: `lib/alaja/components/progress.ex:116`  
**Código**: `case :io.getopts(:standard_error) do {:ok, opts} -> Keyword.get(opts, :tty, false)`  
**Warning**: `The pattern {:ok, _opts} can never match the type. Type: Keyword.t() | {:error, _}`  
**Causa**: `:io.getopts/1` retorna `{:error, _}` o `Keyword.t()` directamente (sin wrapper `{:ok, ...}`) en OTP 27+.  
**Impacto**: Bajo ahora, pero si OTP cambia la semántica el `case` matchearía siempre el primer clause aunque haya error.  
**Recomendación**: Cambiar a `case :io.getopts(:standard_error) do opts when is_list(opts) -> ...; _ -> false end`.

#### P1.3 — ANSI escapes emitidos sin verificar capacidad del terminal

**Archivo**: Múltiples — `lib/alaja/printer.ex`, `lib/alaja/ansi.ex`, `lib/alaja/printer/basics.ex`  
**Problema**: Ninguna función de impresión verifica si `IO.ANSI.enabled?/0` o equivalentes. En tuberías (`stdout |> something`), los escapes ANSI crudos contaminan el output.  
**Ejemplo concreto**: `Alaja.Printer.print_success("ok")` emite `\e[38;2;...m✓ ...\e[0m` incluso cuando stdout no es un TTY.  
**Impacto**: Medio. Afecta a scripts que redirigen stdout a ficheros. Los escapes ANSI aparecen literales.  
**Recomendación**: Implementar un flag global `Alaja.Config.get(:no_color)` o usar `IO.ANSI.enabled?/0` en `print_at_raw` / `print_with_lines`. Mejor si se delega en `Pote.Orchestrator` que ya tiene lógica de degradación.

---

### P2 (🟡) — Debe corregirse cuando se toque el módulo

#### P2.1 — Deprecaciones arrastradas (lib/alaja/components/color_wheel.ex)

**Archivo**: `lib/alaja/components/color_wheel.ex`  
**Símbolos**: `show_color_info/2` (L202), `show_harmony_ring/3` (L228), `show_swatches/2` (L248)  
**Problema**: 3 funciones marcadas `@deprecated` pero aún invocadas desde:
- `test/alaja/components/color_wheel_test.exs` (L93, L100, L110, L119, L128) — 5 usos en tests
- Posibles consumidores externos (arrea, delfos) que usen la API antigua.  
**Impacto**: Bajo. Las funciones equivalentes (`render_color_formats/2`, `render_ascii_wheel/3`, `render_swatch_list/1`) existen.  
**Recomendación**: Migrar los tests a las nuevas funciones y marcar para eliminar en v2.5.0.

#### P2.2 — Módulo `Config` completamente muerto pero accesible como comando

**Archivo**: `lib/alaja/cli/commands/config.ex`  
**Problema**: El comando `config` está mapeado en `Dispatch` pero `run/1` es un no-op. El módulo entero está `@deprecated`. Cualquier consumidor que llame `alaja config ...` obtendría silencio.  
**Impacto**: Bajo (no hay error, solo sorpresa).  
**Recomendación**: O bien eliminar el mapping en `dispatch.ex` y registrar un error informativo, o eliminar el comando por completo.

#### P2.3 — `Alaja.Printer` mezcla responsabilidades de rendering e I/O

**Archivo**: `lib/alaja/printer.ex` (414 líneas)  
**Problema**: El módulo contiene:
- Formateo de chunks a ANSI (debería estar en `ChunkText` o `Renderer`)
- Alineación y padding (cross-cutting, mezclado con lógica de I/O)
- Posicionamiento raw con escapes de cursor
- Box wrapping condicional
- Delegación a `Basics`  
**Sugerencia**: Extraer `Formatter` (apply_formatting, apply_padding, apply_alignment) y `RawPrinter` (print_at_raw, cursor_move). El módulo actual hace demasiado.

#### P2.4 — Constantes duplicadas de ANSI 16-color

**Archivo**: `lib/alaja/components/table.ex` (L429-446) y `lib/alaja/components/box.ex` (L32-49)  
**Problema**: El mismo mapa `@ansi_standard_colors` (0..15 → RGB) está definido en dos sitios con valores idénticos.  
**Impacto**: Si se añade un nuevo color base, hay que acordarse de actualizar ambos.  
**Recomendación**: Mover a `Pote` o a `Alaja.Ansi` como constante compartida.

#### P2.5 — Falta de tipos en funciones privadas del renderer de Wizard

**Archivo**: `lib/alaja/wizard/renderers.ex`  
**Problema**: Ninguna función pública (`inline/1`, `compact/1`, etc.) tiene `@spec`. Aunque el módulo es interno (`@moduledoc` lo explicita), la ausencia de tipos dificulta el análisis estático.  
**Recomendación**: Añadir `@spec` a todas las funciones públicas del módulo.

#### P2.6 — I/O directo a stderr sin pasar por el sistema de logging

**Archivo**: `lib/alaja/cli/error_handler.ex`  
**Problema**: Todas las funciones usan `IO.puts(:stderr, ...)` en lugar de `Logger.warning()` o similar. En modo biblioteca (no escript), los errores de CLI se pierden si el caller no captura stderr.  
**Recomendación**: Añadir un mecanismo de callback o Logger opcional, manteniendo stderr como fallback.

#### P2.7 — `Clock` genérico no detenido en test (GenServer crash en test suite)

...

#### P2.8 — 6 componentes usan RGB fijo, no resuelven colores vía Pote

**Archivos**: `lib/alaja/components/box.ex`, `header.ex`, `bar.ex`, `breadcrumbs.ex`, `separator.ex`, `animated_bar.ex`, `pulsar.ex`  
**Problema**: Estos componentes usan colores RGB hardcodeados en `@default_*` en lugar de resolverlos a través de `Pote.Orchestrator.parse_color/1` o `Cell.safe_pote_color/1`. Cambiar el tema de Alaja no afecta a estos componentes.

**Evidencia**:
| Componente | Default actual | Cómo debería resolverse |
|---|---|---|
| `Box` | `@default_border_color {0, 180, 216}` | `:primary` del tema activo |
| `Header` | `@default_color {0, 180, 216}` | `:primary` del tema activo |
| `Bar` | `@default_filled_color {0, 180, 216}` | `:success` del tema activo |
| `Breadcrumbs` | `@default_item_color {0, 180, 216}`, `@default_current_color {255, 255, 255}` | `:primary` / `:text` del tema |
| `Separator` | `@default_color {64, 64, 64}` | `:muted` del tema activo |
| `AnimatedBar` | RGB fijo en cada frame | Color del tema + gradiente |
| `Pulsar` | RGB fijo en wave | `:primary` con gradiente |

**Contraste**: `Message`, `Table`, `Json` y `ColorWheel` SÍ resuelven colores vía Pote. Inconsistencia interna.

**Impacto**: Medio. Un usuario que instale un tema oscuro verá los headers y bordes en el mismo cyan hardcodeado. La experiencia temática es parcial.

**Recomendación**: Migrar los defaults de estos 7 componentes a átomos de color (`:primary`, `:success`, `:muted`, etc.) que se resuelvan mediante `Cell.safe_pote_color/1`. Aceptar tanto `{r,g,b}` como átomos en las opciones de color (`Keyword.get(opts, :color, :primary)`).

**Síntoma**: Durante `mix test`, aparece `GenServer #PID<...> terminating` con `FunctionClauseError` en `StringIO.state_after_read/4` porque `IO.gets("")` recibe un atom vacío (`:""`).  
**Causa**: Algún test invoca `IO.gets` a través de `Interactive` sin mockear stdin, y ExUnit captura el output causando un estado inconsistente en `StringIO`.  
**Impacto**: El error no hace fallar el test (se rescata), pero es un falso positivo en el log.  
**Recomendación**: Investigar qué test específico causa el problema y mockear `IO.gets` o configurar `ExUnit` con `capture_io` apropiado.

---

### P3 (🟢) — Conveniencia o estilo

#### P3.1 — Variables no usadas en tests

**Archivos**: 
- `test/alaja/components/animated_bar_test.exs:32` — `result =` no usado
- `test/alaja/print_raw_buffer_test.exs:19` — alias `Buffer` no usado
- `test/alaja/components/components_test.exs:4` — alias `Components` no usado

**Recomendación**: Prefijar con `_` o eliminar.

#### P3.2 — `Alaja.Helpers` tiene interfaces legacy (tuple-based rendering)

**Archivo**: `lib/alaja/helpers.ex`  
**Problema**: `box/5` y `double_box/5` devuelven listas de `{x, y, text}` en lugar de `Buffer.t()`. Es una API pre-Buffer que los consumidores (¿delfos?) pueden estar usando.  
**Recomendación**: Añadir variantes que devuelvan Buffer y marcar las legacy con `@deprecated`.

#### P3.3 — Módulo `Alaja.Wizard` no tiene tests específicos de renderer

**Archivo**: Ninguno — `test/alaja/wizard_test.exs` no existe o es muy básico  
**Problema**: Los 5 renderers (`inline`, `compact`, `stacked`, `wizard`, `compact_wizard`) no tienen test unitarios que verifiquen la forma del Buffer generado.  
**Recomendación**: Añadir tests de forma mínimos (ancho, alto, contenido textual de cada celda).

#### P3.4 — `mix test` output muy verboso por escapes ANSI

**Problema**: La suite imprime ~50 líneas de output ANSI coloreado (barras, cajas, gradientes) porque algunos tests no capturan `IO.write`/`IO.puts`. Dificulta leer resultados.  
**Recomendación**: Usar `capture_io` sistemáticamente en tests que invoquen `print_*` o `render_*` con side effects.

---

## 2. Análisis de los 2 snapshot failures

```
Test "Json snapshots simple map" — FAILED
Expected: \e[38;2;205;214;244m{\e[0m  → ro, 205,214,244 = "#CDD6F4" (Catppuccin)
Actual:   \e[38;2;236;239;244m{\e[0m  → ro, 236,239,244 = "#ECEFF4" (Nord)
```

**Causa**: El tema por defecto de Pote cambió su paleta de colores base. Los colores de `keywords`, `string`, `number` y `plain` en `Pote.ColorInfo`/`Pote.Defaults` ahora resuelven a valores distintos. Las snapshots se capturaron con la paleta anterior.  
**Diagnóstico**: No es un bug de Alaja. Es *expected drift* — el snapshot test es frágil por diseño cuando depende de un tema externo.  
**Mitigación**: 
1. Ejecutar `UPDATE_SNAPSHOTS=1 mix test` para regenerar
2. Considerar snapshot tests parametrizados por tema (ej: "json_simple_nord", "json_simple_catppuccin")
3. O cambiar a aserciones estructurales (regex sobre el patrón ANSI, no byte-equality)

---

## 3. Cobertura de tipos

| Módulo | `@spec` pública | Cobertura estimada |
|---|---|---|
| `Alaja` (facade) | 10/10 funciones | 100% |
| `Cell` | 10/10 | 100% |
| `Buffer` | 25/25 | 100% |
| `Printer` | 12/14 (raw 2/3 con overloads) | ~90% |
| `CLI.Definition` | Macro-heavy, 5/5 specs en runtime | 100% |
| `Components.*` | ~35/38 | ~92% |
| `Syntax.*` | 8/10 | ~80% |
| `Wizard` | 5/6 (render) | ~83% |
| `Wizard.Renderers` | 0/5 | 0% |

**Conclusión**: Tipado fuerte y consistente. Las únicas lagunas están en `Wizard.Renderers` (interno, aceptable) y algunas funciones privadas que sería bueno documentar.

---

## 4. Manejo de errores

### No-TTY / color no soportado

| Módulo | Comportamiento |
|---|---|
| `Alaja.Terminal` | Fallback a {80, 24} en `:io.columns/0` error |
| `Alaja.Config` | Silencia errores de lectura de ficheros (`load!` nunca lanza) |
| `Alaja.Cell` | `normalize_color/1` devuelve `nil` para valores inválidos |
| `Alaja.Components.Progress` | Detecta TTY en stderr; desactiva animación si no es TTY |
| `Alaja.Printer.*` | **No verifica** — emite ANSI siempre |
| `Alaja.Components.Table` | **No verifica** — emite ANSI siempre |
| `Alaja.CLI.Help` | **No verifica** — emite ANSI siempre |

**Brecha**: No hay un punto único de decisión "¿emitir ANSI?" que respete `IO.ANSI.enabled?/0` o `Alaja.Config.get(:no_color)`. Cada `render_formatted` en Table y Box construye escapes sin preguntar.

### Propuesta de correción

Añadir en `Alaja.Config`:

```elixir
def color_enabled? do
  get(:no_color, false) == false and IO.ANSI.enabled?()
end
```

Y usarlo en `Cell.build_ansi_prefix/1`, `ChunkText.render/1`, y `Table.render_formatted/3`.

---

## 5. Complejidad

### Top 5 módulos por líneas

| Módulo | LOC | Responsabilidad | Evaluación |
|---|---|---|---|
| `Components.Table` | 1135 | Renderizado de tablas (iodata + Buffer + ANSI parsing + paginación) | **🔴 Sobredimensionado** — mezcla 4 subsistemas |
| `Buffer` | 771 | Grid 2D + composición (hstack/vstack/overlay/crop) | 🟡 Aceptable por la cantidad de operaciones |
| `ColorWheel` | 670 | Análisis de color + armonías + representación ASCII | 🟡 Separable en sub-módulos |
| `CLI.Definition` | 548 | DSL (macro) + dispatch + flag parsing + validación | 🟡 Un archivo para 4 concerns distintos |
| `Printer` | 414 | Dispatcher + formato + alineación + raw I/O | 🟡 Extraer formato y raw I/O |

### Complejidad ciclomática

| Función | Complejidad estimada | Nota |
|---|---|---|
| `Table.render_formatted/3` | Baja | 2 clauses |
| `Table.build_config/2` | Alta (~12 paths) | Construye todo el `Config` struct |
| `Buffer.do_row_to_iodata/6` | Media (~6 paths) | Coalescencia de ANSI con estado |
| `Definition.parse_matched_flag/4` | Alta (5 clauses) | 5 aridades distintas |
| `Printer.print/2` | Media (3 clauses) | Polimórfico por tipo de entrada |

---

## 6. Cross-project consistency (ecosistema Pote)

### Integraciones correctas

- ✅ `Alaja.Theme` usa `Pote.Theme` con `use Pote.Theme, config_app: :alaja` — correcto
- ✅ Override de `storage_dir/0` para respetar `ALAJA_THEMES_PATH`
- ✅ `Alaja.Config.lookup_theme_color/1` implementa el resolver bridge esperado por `Pote.Orchestrator`
- ✅ `Cell.safe_pote_color/1` usa `Pote.resolve_theme_color/1` (el resolver stack)
- ✅ `Alaja.CLI.Parser.parse_color/1` usa `Pote.Orchestrator.parse_color/1`
- ✅ `ChunkText` usa `Pote.ColorInfo` para representación de color

### Integraciones incorrectas / frágiles

- ⚠️ `Alaja.ImageRenderer` usa `apply(Trebejo.Image, func, args)` — Trebejo no está en `deps` y no hay mock en tests. Si se elimina Trebejo, `image` dejaría de funcionar silenciosamente.
- ⚠️ `Alaja.Printer.get_terminal_width/0` duplica lógica de `Alaja.Terminal.width/0` — debería delegar.
- ⚠️ `Alaja.Config` reimplementa persistencia JSON que `Pote.Theme` ya maneja internamente. Posible divergencia de formatos.

---

## 7. Deprecaciones activas

| Símbolo | Módulo | Alternativa | Usos en test |
|---|---|---|---|
| `show_color_info/2` | `ColorWheel` | `render_color_formats/2` + `render_color_variants/1` | 3 |
| `show_harmony_ring/3` | `ColorWheel` | `render_ascii_wheel/3` + `render_swatch_list/1` | 1 |
| `show_swatches/2` | `ColorWheel` | `render_swatch_list/1` | 1 |
| `Config` (módulo) | `CLI.Commands` | `Theme` | 0 (solo test de dispatch) |
| `render_frame/5` | `Pulsar` | `render_buffer/1` | 0 |

---

## 8. Cobertura de tests

### Por módulo (estimado)

| Módulo | Tests | Cobertura | Notas |
|---|---|---|---|
| `Alaja.Cell` | `cell_test` + `cell_engine_test` | ~95% | Bueno |
| `Alaja.Buffer` | `buffer_test` | ~85% | Faltan tests de crop/pad con buffers vacíos |
| `Alaja.Printer` | `printer_test` + `printer_expanded_test` | ~90% | Bueno |
| `Components.Table` | `table_test` + snapshot | ~80% | Faltan tests de paginación |
| `Components.Box` | snapshot + `components_test` | ~75% | Bueno |
| `CLI.Definition` | `definition_test` + `dispatch_test` | ~85% | Extenso |
| `Wizard` | wizard_test | ~60% | Faltan tests de renderers |
| `Syntax` | syntax_test | ~70% | Faltan tests de tokenizadores |

### Snapshot tests vs. unitarios

18 snapshots cubren 6 componentes. Los snapshots son frágiles (tema), pero los unitarios son sólidos. Balance aceptable.

---

## 9. Documentación

### Puntos fuertes
- ✅ `@moduledoc` en todos los módulos públicos
- ✅ `@doc` con ejemplos en casi todas las funciones públicas
- ✅ Documentación de tipos con `@type` (Cell, EffectInfo, MessageInfo, etc.)
- ✅ CHANGELOG.md bien mantenido

### Puntos débiles
- ⚠️ `Alaja.CLI.Dispatch` — 30 funciones sin `@doc` individual. Cada una solo delega, pero el usuario no sabe qué hace cada una sin mirar el destino.
- ⚠️ `Alaja.Wizard.Renderers` — 0 `@spec`, 0 `@doc` en funciones públicas
- ⚠️ `Alaja.ImageRenderer.PNG` (no leído, pero probablemente sin docs)
- ⚠️ Algunas funciones `@doc false` tienen comportamiento no trivial (ej: `Alaja.Config.ensure_loaded/0` que es pública pero marcada false)

---

## Cómo usar esta auditoría

### Interpretación

- **P0 (🔴)**: Debe corregirse antes de cualquier release. Riesgo de crash, seguridad, o pérdida de datos.
- **P1 (🟠)**: Debe corregirse en el próximo ciclo. Degradación significativa de calidad o seguridad.
- **P2 (🟡)**: Debe corregirse cuando se toque el módulo afectado. Deuda técnica.
- **P3 (🟢)**: Conveniencia o estilo. Bajo impacto.

### Flujo de trabajo autónomo

Este documento, junto con `ARCHITECTURE.md` (diseño del proyecto) e `INDEX.md` (navegación de docs), contiene toda la información necesaria para abordar las correcciones de forma autónoma:

1. **Lee ARCHITECTURE.md** primero — entiende el diseño, subsistemas y decisiones clave.
2. **Lee INDEX.md** — localiza los archivos y módulos relevantes.
3. **Vuelve a esta auditoría** — prioriza por severidad (P0 → P1 → P2 → P3).
4. **Para cada hallazgo**: el fichero y línea están indicados. El código fuente relevante está en `lib/`.
5. **Ejecuta `mix test`** antes y después para medir el impacto.
6. **Ejecuta `mix credo --all`** para garantizar que no introduces nuevas violaciones.
7. **Si el hallazgo implica cambiar una interfaz pública**, verifica los proyectos consumidores (listados en ARCHITECTURE.md §consumed-by).

### Dependencias entre proyectos

Alaja depende de **pote** (colores y temas) y, transitivamente, de **apero**. Se recomienda leer las auditorías en este orden:
1. `../apero/docs/AUDIT.md` — fundación
2. `../pote/docs/AUDIT.md` — temas y colores
3. Este documento — UI/TUI

Alaja es consumido por **arrea** (CLI framework), **delfos** (todos los componentes UI), y cualquier aplicación que use el DSL de CLI. Si modificas una interfaz pública (componentes, temas, highlighting), verifica que arrea y delfos siguen compilando.

### Checklist por severidad

**Al corregir un P0**:
- [ ] Aísla la causa raíz (línea exacta)
- [ ] Escribe un test que reproduzca el fallo **antes** de corregir
- [ ] Aplica la corrección
- [ ] Verifica que el test pasa
- [ ] Ejecuta `mix test` — todos deben pasar (los 2 snapshot failures son esperados)
- [ ] Ejecuta `mix credo --all` — cero nuevas violaciones
- [ ] Si cambia una interfaz pública, verifica proyectos consumidores

**Al corregir un P1**:
- [ ] Identifica todos los lugares donde se aplica el patrón (grep por el código similar)
- [ ] Testea el cambio (unitario + integración si aplica)
- [ ] Verifica `mix test` no introduce nuevas roturas
- [ ] Si afecta a consumidores, ejecuta sus tests también

**Al corregir P2/P3**:
- [ ] Corrige cuando toques el módulo por otra razón (boy-scout rule)
- [ ] No merecen un esfuerzo dedicado si no hay un bug reportado
