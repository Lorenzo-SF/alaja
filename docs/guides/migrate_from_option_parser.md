# Migrating from `OptionParser` to `Alaja.CLI.Definition`

> **Audience**: Elixir developers using stdlib `OptionParser` for their CLI
> and wanting more declarative ergonomics (help text, types, validators,
> sub-commands, completion).

`Alaja.CLI.Definition` is a thin DSL on top of `OptionParser` that adds:

1. **Declarative sub-commands** with explicit `usage`, `description` and
   typed flags.
2. **Built-in help rendering** (TTY → tabbed interactive, pipe → flat).
3. **Global options** extracted once and forwarded to every sub-command.
4. **`@spec`-driven dispatch** so the compiler knows the parsed shape.
5. **Pluggable validators** (`validate:` + `:integer`, `:string`, `:atom`).

## Before (OptionParser)

```elixir
defmodule MyCLI do
  def main(argv) do
    {opts, args} =
      OptionParser.parse!(argv,
        strict: [verbose: :boolean, port: :integer, format: :string],
        aliases: [v: :verbose, p: :port, f: :format]
      )

    cond do
      Enum.member?(args, "serve") -> serve(opts, args)
      Enum.member?(args, "build") -> build(opts, args)
      true ->
        IO.puts("Usage: mycli <serve|build> [--verbose] [--port N] [--format F]")
        System.halt(2)
    end
  end
end
```

## After (`Alaja.CLI.Definition`)

```elixir
defmodule MyCLI do
  use Alaja.CLI.Definition

  alias Alaja.CLI.GlobalOpts

  global_opts do
    flag :verbose, :boolean, alias: :v, default: false
    flag :port,    :integer,  default: 4000
    flag :format,  :string,   default: "json"
  end

  command :serve do
    argument :host, :string, default: "localhost"
    run fn %{verbose: v, port: p}, %{host: h} -> start_server(h, p, v) end
  end

  command :build do
    flag :output, :string, alias: :o, default: "dist/"
    run fn %{format: f, output: o}, _ -> build(f, o) end
  end
end
```

## What changes

| Concern | OptionParser | Alaja.CLI.Definition |
|---------|--------------|----------------------|
| Sub-command dispatch | Manual `cond`/`case` | `command :name do ... end` |
| Help text | Manual `IO.puts` | `alaja <cmd> --help` automatic |
| Global flags | Re-parsed per command | Parsed once, forwarded |
| Type coercion | `:integer`, `:boolean` etc | Same + custom validators |
| Aliases (`-v` = `:verbose`) | `aliases: [v: :verbose]` | `flag :verbose, alias: :v` |
| Validation errors | Manual | Automatic + exit code 2 |

## Help output

`alaja mycli --help` on a TTY produces a tabbed view with sections
(Overview / Display / Stateful / Interactive / Color / Action / Theme /
Examples). On a pipe or redirect it prints the same sections sequentially.

`alaja mycli serve --help` shows the per-command help.

## Compatibility

`Alaja.CLI.Definition` returns a struct compatible with the `OptionParser`
shape (a keyword list of parsed options + positional args). You can keep
your existing code that pattern-matches on `:verbose`, `:port`, etc.

## What you don't get (yet)

* Sub-command abbreviations (`mycli s` → `serve`).
* Fish/zsh completion script generation.
* Reading env vars as defaults (use `Alaja.Config`).

## When NOT to migrate

* Single-command CLIs with no sub-commands — the DSL overhead isn't worth it.
* CLIs that need shell-completion today.
* Libraries, not apps (`Alaja.CLI.Definition` is meant for `Application`-style CLIs).