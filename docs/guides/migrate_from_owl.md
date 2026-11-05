# Migrating from `Owl` to `Alaja`

> **Audience**: Elixir developers using `Owl` for terminal output and
> wanting richer theming, truecolor, syntax-highlighted JSON, animated
> bars and interactive stateful components.

`Owl` is great for `IO.puts`-style data output. `Alaja` is for **rich,
branded CLIs** that need consistency across every primitive. Think of it
as the difference between `printf` and a design system.

## Owl one-liner vs Alaja equivalent

```elixir
# Owl
Owl.IO.puts(["Build ", Owl.Data.tag("OK", :green)])

# Alaja
Alaja.CLI.Commands.Show.Message.run(["success", "Build OK"])
```

`Owl.Data.tag/2` is a single character-level color escape. `Alaja`'s
typed messages add a checkmark icon, an alert level, and the theme's
`success` color automatically.

## Side-by-side

| Owl API                  | Alaja equivalent                                  | Notes |
|--------------------------|---------------------------------------------------|-------|
| `Owl.IO.puts(text)`      | `Alaja.print_raw(text)`                           | Plain output |
| `Owl.Data.tag/2`         | `Alaja.Cell` / `Alaja.Components.Table`           | Cell-level colors |
| `Owl.IO.ANSI`            | `Alaja.ANSI`                                      | Same ANSI codes |
| `Owl.Table.new/1`        | `Alaja.Components.Table.render/2`                 | Alaja adds truecolor + themes |
| (no equivalent)          | `Alaja.CLI.Commands.Show.AnimatedBar.run/1`       | Animated progress |
| (no equivalent)          | `Alaja.CLI.Commands.Show.Json.run/1`              | Syntax-highlighted JSON |
| (no equivalent)          | `Alaja.CLI.Commands.Show.Tabs.run/1`              | Stateful tabbed UI |
| (no equivalent)          | `Alaja.CLI.Commands.Show.Menu.run/1`              | Interactive menu |
| (no equivalent)          | `Alaja.CLI.Commands.Color.run/1`                  | Color harmonies, WCAG |

## Migrating a `mix` task

**Before** (Owl):

```elixir
defmodule Mix.Tasks.MyTask do
  use Mix.Task

  @shortdoc "Build the project"

  @impl Mix.Task
  def run(_args) do
    Owl.IO.puts(["Building ", Owl.Data.tag(Owl.Data.icon(:building), :cyan)])

    steps = ["compile", "lint", "test"]

    for step <- steps do
      Owl.IO.puts(["  ", Owl.Data.tag("•", :magenta), " #{step}..."])
      # ...
      Owl.IO.puts(["  ", Owl.Data.tag("✓", :green), " #{step}"])
    end

    Owl.IO.puts([Owl.Data.tag("Done", :green)])
  end
end
```

**After** (Alaja):

```elixir
defmodule Mix.Tasks.MyTask do
  use Mix.Task

  @shortdoc "Build the project"

  @impl Mix.Task
  def run(_args) do
    Alaja.CLI.Commands.Show.Header.run(["Build pipeline"])

    for step <- ["compile", "lint", "test"] do
      Alaja.CLI.Commands.Show.Animate.run(["dots", "--label", step, "--duration", "1500"])
      Alaja.CLI.Commands.Show.Message.run(["success", "#{step} done"])
    end

    Alaja.CLI.Commands.Show.Message.run(["happy", "Build complete"])
  end
end
```

`Alaja` automatically picks up the active theme (`~/.config/alaja/theme`)
so the brand colors stay consistent.

## Theming

Owl has no theme system — you call `Owl.Data.tag(text, :red)` and the
color literal is hard-coded.

Alaja reads the active theme (`Alaja.Config.get(:theme_active)`) and
resolves named colors through `Alaja.Cell.resolve_theme_color/1`. Switch
themes with `alaja theme set oceanic-next` and every output updates.

## Migration strategy

1. **Coexistence**: Alaja and Owl don't conflict. Keep Owl for fine-grained
   escapes you need today; use Alaja for new commands and high-level
   output (headers, tables, JSON, animated bars).
2. **Replace incrementally**: every `Owl.IO.puts` that you reach for is
   a candidate for an Alaja typed message or component.
3. **Audit colors**: when you delete `Owl.Data.tag(_, :color)`, look for
   `:green`, `:red`, `:yellow` literals — those should come from the
   theme.

## What Owl does that Alaja doesn't (yet)

* Pipe-friendly streaming output (Alaja buffers via `Buffer.t()`).
* Tag trees (`Owl.Data.tree`).
* Direct ANSI escaping (Alaja exposes `Alaja.ANSI` but not the full
  sequence of escape helpers Owl provides).

For those, keep using Owl alongside Alaja.