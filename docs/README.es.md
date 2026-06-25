# Alaja — Framework CLI declarativo y kit de renderizado para terminal en Elixir

[![Hex version](https://img.shields.io/badge/hex-1.0.0-blue.svg)](https://hex.pm/packages/alaja)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/Lorenzo-SF/alaja)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Alaja es un framework CLI declarativo y kit de renderizado para terminal en
Elixir. Define comandos con un DSL, valida flags, genera ayuda automática y
renderiza salida de terminal enriquecida — tablas, headers, cajas, barras,
breadcrumbs, resaltado de sintaxis JSON, degradados y prompts interactivos
— todo con secuencias ANSI de color verdadero (24-bit).

Alaja es un framework CLI declarativo y kit de renderizado para terminal,
publicado como librería independiente. Depende de
[Pote](https://github.com/lorenzo-sf/pote) para la gestión de colores,
resolución de temas y conversiones de formato.

---

## Inicio rápido

Agrega `alaja` y `pote` a tu `mix.exs`:

```elixir
def deps do
  [
    {:alaja, github: "Lorenzo-SF/alaja"}
    {:pote, github: "Lorenzo-SF/pote"}
  ]
end
```

### Define un CLI en 5 minutos

```elixir
defmodule MiApp.CLI do
  use Alaja.CLI.Definition, otp_app: :mi_app

  command "deploy", "Despliega a producción" do
    flag :env, :string, default: "staging", values: ~w(staging production)
    flag :force, :boolean, default: false
    argument :version, :string, required: true

    run fn opts ->
      Alaja.print_success("Desplegando v#{opts.version} en #{opts.env}...")
      if opts.force, do: Alaja.print_warning("¡Modo forzado activado!")
    end
  end

  command "status", "Muestra el estado del sistema" do
    run fn _opts ->
      Alaja.Components.Table.print(
        headers: ["Servicio", "Estado", "Uptime"],
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

Ejecútalo:

```bash
mix run -e 'MiApp.CLI.main(["deploy", "1.2.3"])'
mix run -e 'MiApp.CLI.main(["deploy", "1.2.3", "--env", "production", "--force"])'
mix run -e 'MiApp.CLI.main(["status"])'
```

---

## Capa de renderizado

### Impresión de mensajes (12 niveles de severidad)

```elixir
Alaja.print_success("¡Deploy completado!")       # ✓ verde
Alaja.print_error("Conexión rechazada")           # ✗ rojo negrita
Alaja.print_warning("Uso de disco > 80%")         # ⚠ amarillo
Alaja.print_info("Procesando 12 archivos...")     # ℹ cyan
Alaja.print_debug("PID: 0.1234.5")                # ⚙ púrpura
Alaja.print_notice("Mantenimiento a las 02:00")   # 📢 azul
Alaja.print_alert("¡Pico de CPU detectado!")      # 🔔 warning invertido
Alaja.print_critical("¡Base de datos caída!")     # 🔥 error invertido
Alaja.print_emergency("¡Fallo del sistema!")      # 🆘 parpadeante
Alaja.print_happy("¡Todos los tests pasaron!")    # ✨
Alaja.print_sad("Build falló otra vez...")         # ❄

# Despacho dinámico
Alaja.Printer.print_message(:success, "¡Hecho!")
Alaja.Printer.print_message(:error, "¡Ups!")
```

| Función               | Icono | Estilo            |
| --------------------- | ----- | ----------------- |
| `print_success/1,2`   | ✓     | Verde             |
| `print_error/1,2`     | ✗     | Rojo negrita      |
| `print_warning/1,2`   | ⚠     | Amarillo          |
| `print_info/1,2`      | ℹ     | Cyan              |
| `print_debug/1,2`     | ⚙     | Púrpura           |
| `print_notice/1,2`    | 📢    | Azul              |
| `print_alert/1,2`     | 🔔    | Warning invertido |
| `print_critical/1,2`  | 🔥    | Error invertido   |
| `print_emergency/1,2` | 🆘    | Parpadeante       |
| `print_happy/1,2`     | ✨    | Tema happy        |
| `print_sad/1,2`       | ❄     | Tema sad          |
| `print_message/2`     | —     | Nivel dinámico    |

Todas las funciones aceptan opciones de impresión: `raw: true`, `x:`, `y:`,
`align:`, `verbose:`, `padding:`.

### Entrada interactiva

```elixir
alias Alaja.Printer.Interactive

nombre = Interactive.question("¿Cómo te llamas?")
resp   = Interactive.yesno("¿Continuar?", default: :no)
result = Interactive.question_with_options("Elige:", [{"Sí", :si}, {"No", :no}])
Interactive.menu("Selecciona acción:", [{"Deploy", :deploy}, {"Rollback", :rollback}])
```

### API de impresión (bajo nivel)

```elixir
# Impresión estructurada con chunks
chunks = [
  Alaja.Structures.ChunkText.new(" Error: ", color: :error, effects: [:bold]),
  Alaja.Structures.ChunkText.new("Archivo no encontrado", color: :white)
]
msg = Alaja.Structures.MessageInfo.new(chunks, align: :center, padding: 2)
Alaja.Printer.print(msg)

# Posicionamiento raw
Alaja.Printer.print("Cargando...", raw: true, x: 10, y: 5)

# Modo verbose devuelve string ANSI
ansi = Alaja.Printer.print("Hola", verbose: true)
```

### Estructuras

| Estructura    | Módulo                         | Propósito                         |
| ------------- | ------------------------------ | --------------------------------- |
| `ChunkText`   | `Alaja.Structures.ChunkText`   | Fragmento de texto + color + efec |
| `EffectInfo`  | `Alaja.Structures.EffectInfo`  | Negrita, itálica, parpadeo, etc.  |
| `MessageInfo` | `Alaja.Structures.MessageInfo` | Mensaje compuesto + layout        |

```elixir
chunk = Alaja.Structures.ChunkText.new("Hola", color: "#FF0000", effects: [:bold, :underline])
efectos = Alaja.Structures.EffectInfo.new([:bold, :italic, :blink])
msg = Alaja.Structures.MessageInfo.new([chunk], align: :center, padding: 4)
```

---

## Framework CLI

### DSL (`Alaja.CLI.Definition`)

El DSL declarativo provee las macros `command`, `subcommand`, `flag`,
`argument` y `run`:

```elixir
defmodule MiApp.CLI do
  use Alaja.CLI.Definition, otp_app: :mi_app

  command "build", "Compila el proyecto" do
    flag :release, :boolean, default: false
    flag :arch, :string, default: "amd64", values: ~w(amd64 arm64)
    argument :target, :string, required: true

    run fn opts ->
      IO.puts("Compilando #{opts.target} para #{opts.arch}...")
    end
  end

  subcommand "config", "Gestiona configuración" do
    command "get", "Lee un valor" do
      argument :key, :string, required: true

      run fn opts ->
        value = Alaja.Config.get(String.to_atom(opts.key))
        IO.puts("#{opts.key}: #{inspect(value)}")
      end
    end

    command "set", "Escribe un valor" do
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

Tipos de flag: `:string`, `:integer`, `:float`, `:boolean`, `:atom`.

### Opciones globales (`Alaja.CLI.GlobalOpts`)

12 flags compartidos por todos los comandos, extraídos automáticamente
antes del dispatch:

| Flag           | Corto | Tipo                | Descripción                    |
| -------------- | ----- | ------------------- | ------------------------------ |
| `--help`       | `-h`  | boolean             | Mostrar ayuda                  |
| `--raw`        | `-r`  | boolean             | Posicionamiento ANSI raw       |
| `--pos-x`      |       | integer             | Coordenada X (con `--raw`)     |
| `--pos-y`      |       | integer             | Coordenada Y (con `--raw`)     |
| `--align`      | `-a`  | `left/center/right` | Alineación del texto           |
| `--verbose`    | `-v`  | boolean             | Devolver string ANSI           |
| `--box`        |       | boolean             | Envolver salida en caja        |
| `--box-title`  |       | string              | Título de la caja              |
| `--box-border` |       | atom                | Estilo: `rounded`, `double`... |
| `--box-color`  |       | color               | Color del borde                |
| `--quiet`      | `-q`  | boolean             | Suprimir salida                |
| `--stdin`      | `-s`  | boolean             | Leer JSON de stdin             |

### Sistema de ayuda (`Alaja.CLI.Help`)

Ayuda generada automáticamente con resumen, referencia completa y ayuda
por comando — todo renderizado con los propios componentes de tabla y
header de Alaja.

### Validación (`Alaja.CLI.Validator`)

```elixir
# Verificación de tipos de flags
Alaja.CLI.Validator.validate_flags([%{name: :port, type: :integer, required: true}],
                                    [port: "abc"])
# => {:error, ["--port: expected integer, got 'abc'"]}

# Valores permitidos
Alaja.CLI.Validator.validate_flags([%{name: :env, values: ~w(staging prod)}],
                                    [env: "dev"])
# => {:error, ["--env: 'dev' is not valid. Allowed: staging, prod"]}

# Argumentos requeridos faltantes
Alaja.CLI.Validator.validate_args([%{name: :version, required: true}], [])
# => {:error, ["Missing required argument: version"]}

# Detección de comandos peligrosos
Alaja.CLI.Validator.dangerous?("rm -rf /")
# => true
```

### Manejo de errores (`Alaja.CLI.ErrorHandler`)

Mensajes de error formateados con sugerencias "did you mean?" usando
distancia Jaro, y códigos de salida apropiados:

```bash
$ micli deploi
Error: unknown command 'deploi'

Did you mean?
  deploy

Available commands:
  deploy              Despliega a producción
  status              Muestra el estado del sistema
```

### Utilidades de parseo (`Alaja.CLI.Parser`)

```elixir
# Recolectar flags repetidos
Alaja.CLI.Parser.collect_repeated(~w(--cmd ls --cmd pwd), "--cmd")
# => ["ls", "pwd"]

# Parsear colores
Alaja.CLI.Parser.parse_color("#FF0000")
# => {:ok, {255, 0, 0}}

# Parsear listas de colores
Alaja.CLI.Parser.parse_color_list("#FF0000; #00FF00; #0000FF")
# => {:ok, [{255, 0, 0}, {0, 255, 0}, {0, 0, 255}]}

# Parsear pares CLAVE=VALOR
Alaja.CLI.Parser.parse_env_pair("PATH=/usr/bin")
# => {:PATH, "/usr/bin"}

# Parsear alineación
Alaja.CLI.Parser.parse_align("center")
# => :center
```

### Referencia de comandos integrados

**`Alaja.CLI.Commands.Show`** — 16 subcomandos de salida:

| Subcomando     | Descripción                                        |
| -------------- | -------------------------------------------------- |
| `success`      | Mensaje de éxito con checkmark verde               |
| `error`        | Mensaje de error con cruz roja                     |
| `warning`      | Mensaje de advertencia con triángulo amarillo      |
| `info`         | Mensaje informativo con indicador cyan             |
| `debug`        | Mensaje de debug con indicador púrpura             |
| `notice`       | Mensaje de aviso con indicador azul                |
| `critical`     | Mensaje crítico con indicador magenta              |
| `alert`        | Mensaje de alerta con indicador rojo               |
| `emergency`    | Mensaje de emergencia con indicador parpadeante    |
| `happy`        | Mensaje positivo con indicador verde               |
| `sad`          | Mensaje negativo con indicador azul                |
| `message`      | Mensaje formateado (chunks, colores, efectos)      |
| `table`        | Tablas enriquecidas con bordes y estilos por celda |
| `json`         | JSON formateado con resaltado de sintaxis          |
| `bar`          | Barra de progreso con apariencia personalizable    |
| `animated-bar` | Barra de progreso animada                          |
| `header`       | Header estilizado con subtítulo opcional           |
| `separator`    | Línea divisoria horizontal con texto opcional      |
| `gradient`     | Texto con degradado de color (soporte multi-color) |
| `breadcrumbs`  | Ruta de navegación                                 |
| `box`          | Contenedor con bordes y título opcional            |
| `animate`      | Spinners e indicadores animados                    |
| `image`        | Renderizado de imágenes (kitty/iterm2/sixel/ASCII) |
| `list`         | Lista estilizada con header opcional               |
| `ask`          | Entrada de texto interactiva                       |
| `menu`         | Menú de selección interactivo                      |
| `yesno`        | Pregunta interactiva sí/no                         |

**`Alaja.CLI.Commands.Config`** — Gestión de configuración:

| Acción             | Descripción                        |
| ------------------ | ---------------------------------- |
| `init`             | Inicializar `~/.config/alaja`      |
| `get CLAVE`        | Leer un valor de configuración     |
| `set CLAVE VALOR`  | Escribir un valor de configuración |
| `theme list`       | Listar temas disponibles           |
| `theme set NOMBRE` | Activar un tema                    |
| `--show`           | Mostrar configuración actual       |

---

## Componentes visuales

| Módulo                         | Descripción                                         |
| ------------------------------ | --------------------------------------------------- |
| `Alaja.Components.Table`       | Tablas con bordes, formato por celda/col/fila       |
| `Alaja.Components.Header`      | Título centrado + subtítulo, 3 tamaños              |
| `Alaja.Components.Separator`   | Líneas horizontales con etiqueta centrada opcional  |
| `Alaja.Components.Bar`         | Barras de progreso estáticas, degradados RGB        |
| `Alaja.Components.AnimatedBar` | Barras animadas con GenServer (8 estilos)           |
| `Alaja.Components.Breadcrumbs` | Navegación tipo ruta con separador personalizable   |
| `Alaja.Components.Box`         | Contenedores con bordes (5 estilos)                 |
| `Alaja.Components.Json`        | JSON formateado con resaltado de sintaxis           |
| `Alaja.Components.ColorWheel`  | Rueda HSL, anillos de armonía, muestras, degradados |
| `Alaja.Components.Gradient`    | Rampas de color horizontales via ColorWheel         |

### Ejemplos

**Table** — formato por columna, estilos por fila específica, centrada:

```elixir
Alaja.Components.Table.print(
  headers: ["Servicio", "Estado", "Uptime"],
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
Alaja.Components.Box.print("¡Hola, mundo!", title: "Saludo", border: :rounded)
# ╭─ Saludo ──────────╮
# │ ¡Hola, mundo!     │
# ╰───────────────────╯
```

**Bar**:

```elixir
Alaja.Components.Bar.print(75, 100, label: "Subida", width: 40)
Alaja.Components.Bar.print(60, 100, filled_color: {72, 187, 120}, empty_color: {40, 40, 40})
```

**AnimatedBar** (8 estilos):

```elixir
{:ok, pid} = Alaja.Components.AnimatedBar.start_link(animation: "moon", length: 30)

# Estilos: spinner, kitt, dots, bar, moon, clock, pulse, pulsing_bar
```

**Breadcrumbs**:

```elixir
Alaja.Components.Breadcrumbs.print(["Inicio", "Proyectos", "Zaguan"])
# Inicio › Proyectos › Zaguan
```

**JSON**:

```elixir
Alaja.Components.Json.print(%{nombre: "Zaguan", version: "1.0.0", deps: ["pote", "jason"]})
```

**ColorWheel**:

```elixir
Alaja.Components.ColorWheel.show_color_info({255, 87, 51})
Alaja.Components.ColorWheel.show_harmony_ring({255, 0, 0}, :triad)
Alaja.Components.ColorWheel.show_swatches([{255, 0, 0}, {0, 255, 0}, {0, 0, 255}])
```

Armonías disponibles: `triad`, `complementary`, `analogous`, `square`,
`monochromatic`, `compound`, `split-complementary`.

**Renderizado de imágenes** — Kitty, iTerm2, Sixel o fallback ASCII:

```elixir
Alaja.ImageRenderer.render_file("logo.png", width: 40, height: 20)
protocolo = Alaja.ImageRenderer.detect_protocol()
```

### Modo raw

Imprime en posiciones exactas de la terminal:

```elixir
Alaja.Printer.print("Cabecera", raw: true, x: 0, y: 0, color: :cyan, effects: [:bold])
Alaja.Printer.print("Texto", raw: true, x: 0, y: 2)

# Globalmente desde línea de comandos
# micli status --raw --pos-x 10 --pos-y 5
```

### Degradados

```elixir
Alaja.Helpers.progress_bar(75, 20, {80, 140, 255}, {200, 100, 255})
Alaja.Helpers.lerp({255, 0, 0}, {0, 0, 255}, 0.5)  # => {127, 0, 127}

Alaja.Components.ColorWheel.show_gradient(["#FF0000", "#00FF00", "#0000FF"])
```

### Resaltado de sintaxis

```elixir
# Resaltar un archivo (autodetección de lenguaje)
celdas = Alaja.Syntax.highlight_file("lib/mi_app.ex")

# Resaltar contenido directamente
celdas = Alaja.Syntax.highlight_content(codigo, :elixir)

# Tokenizar una línea
tokens = Alaja.Syntax.tokenize("defmodule Foo do", :elixir)
```

Lenguajes soportados: `:elixir`, `:json`, `:markdown`, `:text`.

---

## Módulos de bajo nivel

| Módulo                | Propósito                                                |
| --------------------- | -------------------------------------------------------- |
| `Alaja.ANSI`          | Generadores puros de escape ANSI (fg, bg, cursor, mouse) |
| `Alaja.Terminal`      | Detección de tamaño de terminal (`{cols, rows}`)         |
| `Alaja.Buffer`        | Cuadrícula 2D con tupla plana, acceso O(1)               |
| `Alaja.Cell`          | Unidad atómica: char + fg/bg RGB + lista de efectos      |
| `Alaja.Helpers`       | Sparklines, barras, cajas, interpolación de color        |
| `Alaja.Syntax`        | Resaltado de sintaxis para Elixir, JSON, Markdown        |
| `Alaja.ImageRenderer` | Renderizado de imágenes (Kitty/iTerm2/Sixel/ASCII)       |
| `Alaja.ImageTerminal` | Detección de protocolos de imagen                        |

**Escapes ANSI**:

```elixir
Alaja.ANSI.fg(0, 180, 216)           # color verdadero foreground
Alaja.ANSI.bg(40, 44, 52)            # color verdadero background
Alaja.ANSI.move_to(10, 5)            # cursor a (col, row)
Alaja.ANSI.hide_cursor()
Alaja.ANSI.alt_screen_on()           # buffer alternativo
Alaja.ANSI.mouse_on()                # tracking de mouse SGR
```

**Motor Buffer + Cell**:

```elixir
buffer = Alaja.Buffer.new(80, 24)
buffer = Alaja.Buffer.put(buffer, 10, 5, "X", {255, 0, 0})
celda = Alaja.Buffer.get(buffer, 10, 5)
Alaja.Buffer.write(buffer)  # volcar a stdout
```

**Helpers**:

```elixir
Alaja.Helpers.braille_spark([10, 50, 90, 30, 70], 5)
Alaja.Helpers.box(1, 1, 40, 10, "Workers", {100, 140, 200})
Alaja.Helpers.double_box(1, 1, 40, 10, "Estadísticas", {180, 130, 80})
```

---

## Configuración

```elixir
# Almacén clave-valor sobre Application env
Alaja.Config.get(:color_depth)           # => :truecolor
Alaja.Config.set(:color_depth, :xterm256)
Alaja.Config.all()                       # todos los valores actuales

# Gestión de temas
Alaja.Config.list_themes()               # => ["default", "dracula", "monokai", ...]
{:ok, datos} = Alaja.Config.load_theme("dracula")

# Temas incluidos: default, dracula, monokai, nord, light
```

Claves configurables: `color_depth`, `theme_active`, `refresh_rate`,
`double_buffer`, `max_workers`, `default_policy`.

---

## Dependencias

| Paquete   | Propósito                                                      |
| --------- | -------------------------------------------------------------- |
| **Pote**  | Gestión de color, resolución de temas, conversiones de formato |
| **Jason** | Serialización JSON                                             |

Dev/herramientas:

| Paquete     | Propósito                   |
| ----------- | --------------------------- |
| Credo       | Linting de código           |
| Dialyxir    | Análisis estático de tipos  |
| ExDoc       | Generación de documentación |
| ExCoveralls | Cobertura de tests          |
| Batamanta   | Empaquetado de releases     |
| Benchee     | Benchmarking                |

---

## Instalación

Agrega `alaja` y `pote` a tu `mix.exs`:

```elixir
def deps do
  [
    {:alaja, path: "../alaja"},
    {:pote, path: "../pote"}
  ]
end
```

Luego ejecuta `mix deps.get`.

---

## Licencia

MIT — consulta [LICENSE](https://github.com/lorenzo-sf/alaja) para más detalles.
