# Alaja Recovery Plan v2 — basado en logs reales

> **Estado al inicio del plan**: 2026-06-30 07:50 Europe/Berlin
> **Branch**: `revert/dsl-v1-restore-stable-then-rebuild` (rama de Lorenzo-SF/alaja)
> **Base**: alaja `18ed56d23` (pre-DSL-v1, último commit bueno, 606 tests / 0 failures)

## Resumen del descubrimiento (con exports analizados)

Hubo **dos sesiones secuenciales** entre el 30 jun 00:25 y 02:30:

### Sesión 1 — Claude Code (MiniMax-M3) — 4 fases planificadas

**Phase 1: Fixes del parser** (todos completados en claude code):
- `parse_matched_flag` regression (paréntesis `--foo=bar` vs `--foo bar`)
- `parse_with_globals` (donde el --help falla — bug que tú viste)
- `cast_arg_value` para `:path, :url, :color, :boolean`
- `AnimatedBar` duplicado `@doc` + `Base64` import en `Image`

**Phase 2: Render commands completos** (casi todo):
- ✅ Crear `Components.Gradient`, `Components.List`
- ✅ Adaptar `Table.render/2` a `(message, opts)`
- ✅ Adaptar `Bar, AnimatedBar, Pulsar, Breadcrumbs`
- 🚧 Phase 2.6 — **en progreso cuando murió la sesión** (migración de `cli.ex`)

**Phase 3 y 4**: nunca las terminó.

Tests: 598/0 passing en ese punto.

### Sesión 2 — OpenCode (MiniMax-M3) — intentó continuar Phase 3/4

**Lo que arregló encima** (patches imperfectos):
- `Pulsar.render/2`, `AnimatedBar.render/2` añadidos (faltaban)
- Handler custom para `breadcrumbs` (porque `Breadcrumbs.render/2` espera lista, no string)
- Stub de `Components.Image` recreado
- Handlers `animated_bar_handler`, `pulsar_handler`, `image_handler`

**Lo que el usuario probó y vio roto** (corresponde al código de la sesión 2):

1. **`success/info/error/debug` iconos en línea separada del texto** —
   `Components.X.render/2` retorna Buffer con icono y texto en posiciones distintas.
   `Printer.print/1` los renderiza en líneas separadas. **Bug del formato**.

2. **`pulsar --direction in --colors "..."` falla con `Pulsar.render/2` undefined** —
   la sesión 2 ya lo arregló después (añadiendo `render/2`).

3. **`table --headers "Name;Status" --rows "API;OK|DB;ERR"` String.split/3 fails** —
   en algún lugar `String.split` recibe `nil`. Probable: la Phase 2.3 (re-fit `Table.render/2`)
   no se propagó totalmente, o el `dispatch_render` pasa opts con `nil` en algún campo.

4. **`gradient --from "#FF6B6B"` "Invalid color format"** —
   `cast_flag_value(:color, "#FF6B6B")` falla porque devuelve sólo lo que `parse_color_opt` reconoce. Hex con `#` no está manejado. **Bug real**.

5. **`header --help`** falla con `unknown_globals --help`. **Bug central**: `--help` no está en `accepts_globals` de casi todos los render_command.

6. **`header --box true` se imprime como literal** —
   `--box true` no es la sintaxis correcta. En el DSL es `--box` sin valor (boolean). El usuario pasó `--box true` y el parser lo ve como `--box=true` literal.

7. **`image` y `cast_arg_value` falla con `:path`** — la Phase 1.3 añadió esa cláusula pero
   no llegó al código en producción del usuario.

8. **`json '{"a":1}'` no formatea, escapa las comillas** —
   `Components.Json.render/2` espera algo que no es lo que el agente le pasa.

9. **`alaja color --colors` falla con String.downcase/2** —
   `cast_flag_value` para boolean con flag `--colors` (sin valor), intenta downcase algo que no es string.

10. **`pulsar` parado** — `pulsar` debe animar, pero `render_frame(0)` da un frame estático. La animación **no encaja en render_command** porque necesita loop. Pulsar **debe seguir siendo** `command + run: custom_handler` con el `animate_loop`. Lo que la sesión 2 hizo (`pulsar_handler` que llama `render_frame`) es **incorrecto para pulsar**.

11. **`%` y falta de `\n` final** — `Printer.print/1` no garantiza newline final. Bug fácil.

12. **`alaja separator --color "theme:ternary"` no responde a themes** —
   el DSL pasa el flag como string, no se resuelve el prefijo `theme:`.

## Lo que confirma este plan

1. `git checkout 18ed56d` es el **último commit bueno** (606 tests).
2. La rama `revert/dsl-v1-restore-stable-then-rebuild` ya está pusheada a `Lorenzo-SF/alaja`.
3. NO hemos tocado `main`. Merge desde rama cuando esté lista.

## Decisión del plan v2

**Continuar el trabajo de la sesión 1 de claude code**, completando lo que dejó
a medias. Replicar exactamente:

1. **Phase 2.6** (claude code): completar la migración de `cli.ex` a `render_command`
2. **Bug del `--help`**: añadirlo a globals standards (no requerir `accepts_globals`)
3. **cast_flag_value**: revisar que las cláusulas para `:path, :url, :color, :boolean` están en main
4. **Theme prefix**: que `cast_flag_value(:color, "theme:ternary")` resuelva a `ternary`
5. **Format fix**: pulsar debe usar `command + run:` con loop, no render_command; los demás sí
6. **Output cleanup**: garantizar `\n` final, eliminar `%` residual

NO vamos a:

- Cherry-pick de los 5 commits originales (cruzados, inseguros)
- Cambiar el `:json` a escape completo —我们会 arreglar `Components.Json.render/2`
- Wizard subsystem: lo descartamos por ahora (lo añadió el agente y no se llegó a usar;
  podemos hacerlo en una release futura si hace falta)

## Plan de commits (orden estricto, cada uno autónomo)

### Commit A — `fix(alaja): completar migración render_command (Phase 2.6)`

Migrar todos los `command "x" do ... end run: {Dispatch, :x}` a
`render_command "x" do ... end renders({Components.X, :render}) accepts_globals([...])`.

**Cambios**:
- `lib/alaja/cli.ex` — sólo este archivo. Migrar 16 visual commands. **Pulsar queda con
  `command + run: {Alaja.CLI, :pulsar_handler}` porque pulsar necesita loop.**

**Tests**: snapshot tests de cada command en `test/alaja/cli/cli_commands_test.exs`.
Cada uno verifica que el output coincide con un snapshot guardado.

**Criterio done**: `mix test` pasa. `mix alaja <x>` para todos los `<x>` excepto pulsar funciona.

### Commit B — `fix(alaja): --help siempre global`

En `lib/alaja/cli/definition.ex`, `parse_with_globals/2` debe tratar `--help`,
`--version`, `-h`, `-v` SIEMPRE como globals, no exigir `accepts_globals`.

**Cambios**:
- `lib/alaja/cli/definition.ex` — `parse_with_globals/2`
- `lib/alaja/cli/global_opts.ex` — añadir `--help`, `--version` (ya están, sólo que el DSL los ignora)

**Tests**: `test/alaja/cli/definition_test.exs` — añadir caso "comando sin help en accepts_globals pero alaja pulsar --help devuelve ayuda".

### Commit C — `fix(alaja): cast_flag_value soporta :color_list, :path, :url, themes`

`Alaja.CLI.Definition.cast_flag_value/2` necesita cláusulas para:
- `:color_list` → `["hex:#FF0000", "rgb:255,0,0"]`
- `:path` → expand Path si comienza con `~`
- `:url` → parsea y almacena
- `:color` con prefijo `theme:` → resuelve via Alaja.Theme

**Cambios**:
- `lib/alaja/cli/definition.ex` — `cast_flag_value/2` extender
- `lib/alaja/cli/parser.ex` (o donde esté) — `parse_color_opt/1` reconocer hex con `#`

**Tests**: `test/alaja/cli/options_parser_test.exs` — parametrizar tests con hex, rgb, hsl, theme-prefix.

### Commit D — `fix(alaja): Pulsar vuelve a usar handler animado`

Pulsar no debe ser `render_command` porque necesita loop de animación. Lo dejamos como
`command + run: {Alaja.CLI, :pulsar_handler}` con el `animate_loop` original.

**Cambios**:
- `lib/alaja/cli.ex` — pulsar con `command + run:` (handler con loop)
- (mantener) los `pulsar_handler` ya existentes de la sesión 2, pero que llame
  `Pulsar.animate_loop/4` (no `render_frame(0)`)

### Commit E — `fix(alaja): Printer.print/1 garantiza \n final`

El output de los componentes termina sin `\n` (de ahí el `%\n` que ve el usuario en el
shell). `print_with_lines/2` debe añadir `\n` si no está.

**Cambios**:
- `lib/alaja/printer.ex` — `print_with_lines/2` y `print_at_raw/3`

### Commit F — `fix(alaja): Components.Json.render/2 formatea JSON correctamente`

`alaja json '{"a":1}'` actualmente escapa las comillas y muestra el JSON literal.
El bug es que `Json.render/2` recibe un string escapeado en vez de parsearlo y formatearlo.

**Cambios**:
- `lib/alaja/components/json.ex` — `render/2` primero `Jason.decode!/1` (seguro wrapper),
  luego formatear con Cell engine.

### Commit G (opcional) — `feat(alaja): Components.Typed-Message formato inline`

`success`, `error`, `warning`, `info`, `debug` retornan un Buffer pero el Printer los
renderiza en líneas separadas. Una opción es cambiar `render/2` para retornar
`Alaja.Structures.MessageInfo` con chunks `[ChunkText("✓"), ChunkText(" ", gap:
true), ChunkText("test")]` en lugar de un Buffer simple.

**Cambios**:
- `lib/alaja/components/success.ex` (y los otros 10) — `render/2 → MessageInfo.t()`

### Commit H — `fix(alaja): Ci envuelve pulsar_handler con timeout de 1 frame`

Para que `pulsar` se anime en producción (no se quede en frame 0), pulsar_handler
debe invocar `animate_loop/4` (original) con cursor hidden y timmer. El fix es cambiar
`pulsar_handler` para que use el `animate_loop` original en lugar de `render_frame(0)`.

Lo detallamos mejor al implementar.

## Resumen de prioridades

**Críticos (commits A+B+C+E)** — sin esto, el CLI no funciona razonablemente:
- A: completar migración render_command
- B: arreglar --help
- C: arreglar cast_flag_value con todos los tipos
- E: newline final

**Importantes (commits D+F+H)** — mejoran experiencia pero el CLI funciona sin esto:
- D: pulsar animado
- F: json formateado
- H: format de typed messages

## Cómo validar

1. `mix alaja <cmd>` para cada comando. Ejemplos:
   - `mix alaja success "Build OK"`
   - `mix alaja header "Title" --subtitle "Sub" --box`
   - `mix alaja header --help` (debe dar ayuda, no error)
   - `mix alaja gradient "Hi" --from "red" --to "yellow"`
   - `mix alaja json '{"a":1}'` (debe formatear, no escapar)
   - `mix alaja table --headers "A;B" --rows "1;2|3;4"` (debe tabular)
   - `mix alaja pulsar "Hi" --direction out` (debe animar varios frames antes de parar)

2. `mix alaja color --colors` (debe listar colores del theme actual)
3. `mix test` (debe pasar verde después de cada commit)

## Cierre

Después de commits A-H + tus pruebas + tu OK:
- Tag `v0.4.0-rc1` (o `v0.4.0` directo si todo va bien)
- Push de la rama
- PR a `main`: `revert/dsl-v1-restore-stable-then-rebuild` → `main`
- Cuando merge, delfos puede volver a `mix deps.update alaja` y obtiene el alaja arreglado

## Plan rápido (TL;DR)

1. **A**: terminar `cli.ex` migración
2. **B**: `--help` global
3. **C**: cast_flag_value con todos los tipos
4. **D**: pulsar animado
5. **E**: `\n` final
6. **F**: json formateado
7. (opcional) **G**: typed messages inline

Después de cada uno, `mix test` pasa. Tests añadidos para regresiones nuevas.
