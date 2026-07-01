# Alaja: lo que se pretendió hacer y cómo hacerlo bien

> Documento de aprendizaje después del incidente con el DSL v1.
> Estado: 2026-06-30 07:57 Berlin. Main estable en `18ed56d` (`v0.3.12`).

## Lo que pasó

Sesión 1 (Claude Code, 30 jun 00:25-01:11):
- **Phase 1**: 4 fixes críticos del parser (`parse_matched_flag`, `parse_with_globals`,
  `cast_arg_value` para nuevos tipos, AnimatedBar/Image).
- **Phase 2**: Mover componentes a `Components.X.render/2 → Buffer.t()` (Table, Bar,
  AnimatedBar, Pulsar, Breadcrumbs). Crear `Components.Gradient, List` desde cero.
- **Phase 2.6**: Re-migrar `cli.ex` con `render_command` en vez de `command + run:` →
  **no terminó**.

Sesión 2 (OpenCode, después):
- Intentó continuar Phase 3/4 con visión parcial.
- Añadió parches a Pulsar, AnimatedBar (render/2), Image stub.
- Creó `pulsar_handler`, `image_handler`, `breadcrumbs_handler`, `animated_bar_handler`
  como **workarounds** en lugar de completar la migración de `cli.ex`.

**Resultado**:
- `commands/show/*.ex` borrados en el código real
- `cli.ex` referencia `Dispatch → Show.X` que no existe
- Componentes funcionan pero pulsar/json/etc devuelven formato feo
- `--help`, `--box`, `theme:` colors no funcionan

**Root cause**: el agente 2 no sabía que el agente 1 había dejado Phase 2.6 a medias. Confió
en que las referencias a `Dispatch` funcionaban porque la rama era "completada" (los
mensajes de commit lo indicaban).

## Lo que se pretendía hacer (entendimiento real)

### Concepto: el CLI es para usuarios, no para desarrolladores

`alaja json '{...}'` debe ser bonito, no una primitiva que el developer parchea después.
Pero `alaja json` no tiene que exponer "todo JSON". El usuario final quiere ver
resultados, no implementación. Por eso se hacían **dos cosas distintas con el DSL**:

1. **Commands de gestión** (no visuales): `color, config, action, ask, menu, yesno`.
   Usan `command + run:` con un handler normal.
2. **Commands visuales** (renderizan): `success, error, warning, info, debug, critical,
   alert, emergency, happy, sad, message, header, separator, gradient, table, json,
   bar, animated-bar, breadcrumbs, animate, pulsar, image, list`. Usan
   `render_command` que delega al component y print.

El DSL v1 quería **declarar en una sola línea**: nombre, descripción, render objetivo,
qué globals acepta. Algo como:

```elixir
render_command "header", "Styled header with optional subtitle" do
  argument :title, :string, required: true
  flag :subtitle, :string
  flag :size, :atom, values: [:small, :medium, :large], default: :medium
  flag :color, :color
  renders({Alaja.Components.Header, :render})
  accepts_globals([:raw, :pos_x, :pos_y, :align, :box, :box_title, :box_border, :box_color, :quiet])
end
```

El sistema tiene:
- `argument :name, :type, opts` (incl. `required: true/false`, `default: ...`)
- `flag :name, :type, opts` (incl. `default`, `values: [:a, :b, ...]`, `short: :h`, `repeatable: true`)
- `accepts_globals([:raw, :align, ...])` — qué globals aplica este comando
- `renders({Mod, Fun})` — tupla `{Mod, Fun}` que se llama con `(message, opts)` y retorna `Buffer.t()`
- `run({Mod, Fun})` para commands que no son visuales (alternativa a `renders`)

### El bug raíz es simple y viejo

`accepts_globals([...])` exige declarar manualmente. Si olvidas `--help`, el comando
no responde a `alaja pulsar --help`. **Eso es inaceptable.** `--help` y `--version`
deberían ser SIEMPRE globales, sin pedirlo.

### Wizard subsystem

El agente 1 construyó wizards multi-step en `lib/alaja/wizard/`. Es **un buen feature**
que vale la pena migrar. Pero NO con renderers "opencode, claude_code, branded,
compact, menu" — son nombres circunstanciales. Nombres neutros:

- `:inline` (sigue el flujo normal, paso a paso con prefijo prompt)
- `:compact` (todo en una línea, `> [1] option  [2] another`)
- `:stacked` (cada respuesta en columna)
- `:wizard` (flujo guiado con header título por step)
- `:compact_wizard` (header + inline)

Estos nombres describen **el formato visual**, no el consumer del CLI. Esa es la
diferencia. Si mañana cambias de IDE, no hay que renombrar renderers.

### Configurable CLI

Tú insististe en esto: el CLI debe permitir:

- **Argumentos** posicionales y `--flag`
- **Archivos de config** (default `~/.config/alaja/config.toml` o YAML)
- **Variables de entorno** (ej. `ALAJAX_FOO=bar`)
- **Flags runtime** (lo de siempre)

El DSL de alaja tenía soporte parcial para args/flags. Faltaba:
- **Cargar config al iniciar** (`Alaja.CLI.Config.load(:delfos)`)
- **Inyectar config-as-flags** en commands que lo pidan

Eso requiere una capa **fuera** del `Alaja.CLI.Definition`: el `App.start/2` que
carga config antes que arranque el comando. Ese patrón ya está en `Delfos.Application`.

## Lo que hay que hacer (plan nuevo, no el del agent)

### Fase 1: Tests sagrados

Antes de tocar nada de código nuevo, **construir la red de seguridad**. Smoke tests
que ejecutan binarios reales y capturan output. Si el formato cambia accidentalmente,
los tests rompen.

```
test/alaja/cli/smoke/
├── success_test.exs        # alaja success "Hello" -> ✓ Hello\n
├── error_test.exs          # alaja error "Boom" -> ✗ Boom\n
├── header_test.exs          # alaja header "Title" --subtitle "Sub" -> ▟ Title ▟\n
├── separator_test.exs       # alaja separator --text "X" -> ─── X ───\n
├── gradient_test.exs        # alaja gradient "Hi" --from red --to blue -> colored\n
├── table_test.exs           # alaja table --headers "A;B" --rows "1;2|3;4" -> tab\n
├── json_test.exs            # alaja json '{"a":1}' -> formatted JSON
├── pulsar_test.exs          # alaja pulsar "Hi" --direction out -> animation frames
├── box_test.exs             # alaja header "X" --box --box-title "T" -> bordered
├── theme_test.exs           # alaja separator --color "theme:ternary" -> themed\n
└── ...
```

**Estrategia**: los tests ejecutan `mix alaja <args>` como subproceso, capturan
stdout, normalizan los códigos ANSI, comparan con snapshots guardados (ASCII
form). Si alguien cambia el formato, el snapshot diff lo detecta.

**Importante**: los snapshots se commitean. Para actualizarlos hay que:
1. Cambiar el código
2. Correr `mix alaja <x>` y verificar manualmente que el output es correcto
3. Actualizar el snapshot solo si el cambio es **real y útil**

Esos snapshots son el contrato visual. "Sagrados" significa:
- NO se borran
- NO se actualizan sin revisión humana
- Cualquier diff requiere justificación

### Fase 2: Refactor del DSL (sin prisa)

Una vez los smoke tests pasen, se puede refactorizar el DSL con red de seguridad.
Esta fase es la que el agente 1 quiso hacer. Plan:

**2.1**: Refactorizar `Alaja.CLI.Definition` para tener:
- DSL macro único (`command/3`, `flag/3`, `argument/3`, `run:`, `accepts_globals:`)
- Tipo `:command` (no renderiza, retorna valor o side-effect)
- Tipo `:renderer` (delega a `Components.X.render` para output visual)

```elixir
# No visual:
command "color", "..." do
  argument :color, :string
  flag :harmony, :string
  run {Alaja.CLI.Commands.Color, :run}
end

# Visual:
command "header", "..." do
  argument :title, :string
  flag :subtitle, :string
  renderer Alaja.Components.Header
end
```

`renderer Component` = shorthand para `run {Component, :render}` envuelto en
Printer.print.

**2.2**: `--help` y `--version` siempre globales (sin `accepts_globals`).

**2.3**: `cast_flag_value/2` con todos los tipos:
- `:string`, `:integer`, `:float`, `:boolean`, `:atom`
- `:color` (con prefijo `theme:` o `hex:#ff0000` o `rgb:255,0,0`)
- `:color_list` (lista separada por `;`)
- `:path` (expande `~`)
- `:url`

**2.4**: `Components.X.render/2 → Buffer.t()` canónico (es lo que el agente 1 quería
con Phase 2.1-2.5, pero completado).

**2.5**: Migrar `cli.ex` command por command, **una a la vez**, con tests snapshot
para cada uno.

### Fase 3: Config externo

`Alaja.CLI.Config` (nuevo módulo):
- Carga `~/.config/alaja/config.toml` si existe
- Lee env vars `ALAJAX_<KEY>` para overrides
- `config_path/0` para descubrir archivos de config

Los consumers (delfos, otros) usan `Alaja.CLI.Config` en su `Application.start/2`:

```elixir
def start(_type, _args) do
  Alaja.CLI.Config.load!(:delfos)
  # ahora config está disponible via Alaja.CLI.Config.get/1
end
```

Los commands que necesitan config lo piden:

```elixir
command "config", "Manage configuration" do
  argument :action, :string, default: "show"
  argument :key, :string
  run {Alaja.CLI.Commands.Config, :run}
end
```

### Fase 4: Wizard subsystem

`Alaja.Wizard` con renderers de **nombres neutros**:

```elixir
defmodule Delfos.SetupWizard do
  use Alaja.Wizard.DSL

  wizard "setup", style: :inline do
    step :provider, kind: :choice do
      prompt "Which provider?"
      choice "OpenAI (cloud, paid)"
      choice "Anthropic (cloud, paid)"
      choice "Local llama.cpp (free)"
    end
    # ...
  end
end
```

Renderers disponibles:
- `:inline` (paso a paso con prefijo prompt, flecha)
- `:compact` (todo en una línea con índices numerados)
- `:stacked` (cada respuesta en columna)
- `:wizard` (flujo guiado con header por step)
- `:compact_wizard` (header + todo en una línea)

`Alaja.Wizard.run(MyWizardModule)` ejecuta la sesión completa.

## Lo que NO se va a hacer

- ❌ NO cherry-pick de los 5 commits problemáticos
- ❌ NO renderers con nombres "opencode", "claude_code", etc — neutralizamos
- ❌ NO más wizards inline de un solo paso (eso es `Alaja.Printer.Interactive.question_with_options`)
- ❌ NO romper la API de `Alaja.CLI.Definition` en la fase 2 (cambios sin breaking)
- ❌ NO `mix release` con `include_erts: true` aún (batamanta puede venir después)

## Lecciones aprendidas (a guardar en memory)

1. **Cuando el contexto se rompe por cambio de herramienta, NO continuar Phase N+1**.
   Mejor guardar el progreso y empezar sesión nueva con buena info.
2. **Borrar archivos `show/*.ex` ANTES de migrar `cli.ex`** fue el error técnico
   principal. La regla: borrado y reemplazo deben ser el MISMO commit atómicamente.
3. **`accepts_globals([...])` no debería ser opcional**. Globals son conventions,
   siempre aplican. Cambiar la API para que se infieran.
4. **Los tests deben correr flujos reales**, no solo "test passes". Snapshots del
   output son la red de seguridad visual.
5. **El DSL macro debería generar `apply(Mod, Fun, ...)` con tupla `{Mod, Fun}`**,
   no lambda closures (que escapan mal). Mantener tuplas para inspección/debug.

## Resumen ejecutivo

**Hoy**: alaja restaurado a `18ed56d` (`v0.3.12`) — funcional y testeado (606 tests).

**Mañana / próxima sesión**:
1. Construir smoke tests primero (~2 horas)
2. Luego refactor del DSL con red de seguridad (~4 horas)
3. Wizard subsystem (~2 horas)
4. Config externo (~1 hora)

**Total**: ~1 día de trabajo bien hecho en lugar de las 4 horas de ayer que se
perdieron.

---

# Estado actual (verificado 2026-06-30 07:57 Berlin)

- ✅ `origin/main` forzado a `18ed56d` (SHA del último commit bueno)
- ✅ `v0.3.12` retagueado apuntando a `18ed56d`
- ✅ Rama `backup/dsl-v1-broken-attempt` (en `c21ae6b`) — por si quieres explorar
- ❌ 5 commits problemáticos borrados del history público (siguen en backup)
- ✅ 606 tests pasan
- ✅ `commands/show/*.ex` funcionales (pulsar, json, table, header, separator, etc.)
- ✅ Componentes `Components.*` estables

**No hay** `Components.Success, Error, Warning, ...` (typed messages) — el agente los
añadió pero no llegaron al main. Lo añadimos en la Fase 2 con los nuevos nombres
correctos.
