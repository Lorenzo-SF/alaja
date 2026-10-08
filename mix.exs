defmodule Alaja.MixProject do
  use Mix.Project

  def project do
    [
      app: :alaja,
      version: "3.2.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Alaja",
      elixirc_paths: elixirc_paths(Mix.env()),
      description:
        "Declarative CLI framework and terminal rendering kit for Elixir — commands DSL, auto-generated help, ANSI rendering, tables, headers, boxes, and interactive prompts.",
      source_url: "https://github.com/Lorenzo-SF/alaja",
      homepage_url: "https://github.com/Lorenzo-SF/alaja",
      package: [
        name: :alaja,
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/Lorenzo-SF/alaja"},
        maintainers: ["Lorenzo Sánchez"]
      ],
      docs: docs(),
      batamanta: batamanta(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Alaja.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/Lorenzo-SF/alaja",
      homepage_url: "https://github.com/Lorenzo-SF/alaja",
      extras: ["README.md", "docs/README_ES.md", "LICENSE.md"],
      groups_for_modules: [
        "Core API": [
          Alaja,
          Alaja.Application,
          Alaja.App,
          Alaja.Cmd,
          Alaja.Sub,
          Alaja.Msg
        ],
        CLI: [
          Alaja.CLI,
          Alaja.CLI.Definition,
          Alaja.CLI.Dispatch,
          Alaja.CLI.Parser,
          Alaja.CLI.Help,
          Alaja.CLI.HelpFormatter,
          Alaja.CLI.HelpTabs,
          Alaja.CLI.Validator,
          Alaja.CLI.GlobalOpts,
          Alaja.CLI.ErrorHandler,
          Alaja.CLI.Exit,
          Alaja.CLI.ActionError,
          Alaja.CLI.Color,
          Alaja.CLI.NoColor,
          Alaja.CLI.Pagination,
          Alaja.CLI.Picker,
          Alaja.CLI.Showcase,
          Alaja.CLI.ViewText
        ],
        "CLI Commands": [
          Alaja.CLI.Commands.Base,
          Alaja.CLI.Commands.Action,
          Alaja.CLI.Commands.Color,
          Alaja.CLI.Commands.Theme,
          Alaja.CLI.Commands.Show.Animate,
          Alaja.CLI.Commands.Show.AnimatedBar,
          Alaja.CLI.Commands.Show.Ask,
          Alaja.CLI.Commands.Show.Bar,
          Alaja.CLI.Commands.Show.Breadcrumbs,
          Alaja.CLI.Commands.Show.Gradient,
          Alaja.CLI.Commands.Show.Header,
          Alaja.CLI.Commands.Show.Image,
          Alaja.CLI.Commands.Show.Json,
          Alaja.CLI.Commands.Show.List,
          Alaja.CLI.Commands.Show.Menu,
          Alaja.CLI.Commands.Show.Message,
          Alaja.CLI.Commands.Show.Pulsar,
          Alaja.CLI.Commands.Show.Separator,
          Alaja.CLI.Commands.Show.Table,
          Alaja.CLI.Commands.Show.YesNo
        ],
        Components: [
          Alaja.Components,
          Alaja.Components.Animate,
          Alaja.Components.AnimatedBar,
          Alaja.Components.Bar,
          Alaja.Components.Box,
          Alaja.Components.Breadcrumbs,
          Alaja.Components.ColorWheel,
          Alaja.Components.ColorWheel.Harmonies,
          Alaja.Components.ColorWheel.Info,
          Alaja.Components.ColorWheel.Renderer,
          Alaja.Components.Gradient,
          Alaja.Components.Header,
          Alaja.Components.Json,
          Alaja.Components.List,
          Alaja.Components.Message,
          Alaja.Components.MultiBar,
          Alaja.Components.Progress,
          Alaja.Components.Pulsar,
          Alaja.Components.Separator,
          Alaja.Components.Table,
          Alaja.Components.Table.Borders,
          Alaja.Components.Table.Builder,
          Alaja.Components.Table.Calculator,
          Alaja.Components.Table.Page,
          Alaja.Components.Table.Renderer,
          Alaja.Components.Table.Theme
        ],
        Rendering: [
          Alaja.Printer,
          Alaja.Printer.Basics,
          Alaja.Printer.Formatter,
          Alaja.Printer.Interactive,
          Alaja.Printer.RawPrinter,
          Alaja.Renderer,
          Alaja.Buffer,
          Alaja.Buffer.Position,
          Alaja.Buffer.Range,
          Alaja.Buffer.Renderer,
          Alaja.Buffer.Writer,
          Alaja.Cell,
          Alaja.Frame,
          Alaja.Layout
        ],
        "Syntax & Effects": [
          Alaja.ANSI,
          Alaja.Syntax,
          Alaja.Syntax.Builtin,
          Alaja.Syntax.Engine,
          Alaja.Syntax.Language,
          Alaja.Syntax.Renderer,
          Alaja.Syntax.Special,
          Alaja.Syntax.Theme
        ],
        Structures: [
          Alaja.Structures.ChunkText,
          Alaja.Structures.EffectInfo,
          Alaja.Structures.MessageInfo
        ],
        Theme: [
          Alaja.Theme,
          Alaja.Theme.Bootstrap,
          Alaja.Theme.CustomTemplates,
          Alaja.Theme.RequiredKeys
        ],
        Interactive: [
          Alaja.Wizard,
          Alaja.Wizard.Renderers,
          Alaja.Input,
          Alaja.FocusManager,
          Alaja.View.Node
        ],
        Utilities: [
          Alaja.Config,
          Alaja.Helpers,
          Alaja.Terminal,
          Alaja.ImageRenderer,
          Alaja.ImageRenderer.PNG,
          Alaja.ImageTerminal,
          Alaja.Text,
          Alaja.Backend,
          Alaja.Backend.Tty,
          Alaja.TestBackend
        ],
        "Mix Tasks": [
          Mix.Tasks.Alaja.Demo,
          Mix.Tasks.Alaja.Snapshot
        ]
      ],
      source_ref: "3.2.0"
    ]
  end

  defp batamanta do
    [
      format: :release,
      execution_mode: :cli,
      compression: 19,
      binary_name: "alaja",
      show_banner: true,
      # The warm-BEAM daemon is OFF, deliberately.
      #
      # It is a big win in a loop — measured on this machine, 50 commands
      # cost 77ms through the daemon against 17.6s booting a VM per
      # command, 230x — but the shape alaja is actually used in is one
      # command at a time:
      #
      #     alaja success "..."
      #     alaja warning "..."
      #     alaja error "..."
      #
      # and at ~0.35s per invocation the pause is visible on every single
      # line. The daemon also costs ~94MB of resident BEAM held open
      # between calls, and it is hostile to any stateful OTP app (a
      # shared warm VM is the opposite of what a GenServer holding
      # cluster state wants).
      #
      # So the default is off, and the whole block is kept as a worked
      # example for projects that DO want it. Flip `enabled: true` (or
      # export `ALAJA_BEAM_ALIVE=<ms>` once the daemon is built into the
      # binary) if you decide the loop case outweighs the interactive one.
      daemon: [
        enabled: false,
        var: "ALAJA_BEAM_ALIVE",
        default_ms: 300_000,
        request_timeout_ms: 60_000,
        # Commands that must own the terminal, so they run in the
        # foreground and never go through the warm BEAM.
        #
        # A daemon buffers the command's output and returns it as a single
        # blob at the end, and it has no stdin. That breaks these three
        # categories outright, with no way to recover inside the daemon:
        #
        #   * animated — every spinner frame arrives at once,
        #   * interactive — the prompt waits on a stdin nobody reads, so
        #     the terminal hangs,
        #   * help — the tab navigator needs arrow keys and would get its
        #     redraws out of order.
        #
        # `--help`, `-h` and a bare `alaja` are always foreground; the
        # wrapper handles those itself, whatever is listed here.
        foreground: [
          # animated
          "animate",
          "pulsar",
          "animated-bar",
          # interactive
          "ask",
          "menu",
          "yesno",
          "picker",
          "showcase"
        ]
      ]
    ]
  end

  defp deps do
    [
      {:pote, "~> 3.0", override: true},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:batamanta, "~> 3.1", optional: true, runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer-ignore-warnings",
      plt_file: {:no_warn, "priv/plts/alaja"},
      plt_add_apps: [:mix]
    ]
  end

  defp aliases do
    [
      gen: ["deps.get", "compile", "batamanta", "install"],
      install: fn _ ->
        dest_dir = Path.expand("~/.local/bin")
        File.mkdir_p!(dest_dir)
        config = Mix.Project.config()
        app_name = Atom.to_string(config[:app])

        source_path = Path.expand("alaja")
        dest_path = Path.join(dest_dir, app_name)

        if File.exists?(source_path) do
          install_binary(source_path, dest_path)
        else
          Mix.shell().error("[ERROR] No se encontro el binario: #{source_path}")
          Mix.shell().info("   Ejecutaste 'mix batamanta' primero?")
        end
      end,
      qa: [
        "format",
        "compile",
        "dialyzer",
        "cmd sh -c 'MIX_ENV=test mix test --cover'",
        "cmd sh -c 'alaja json \"$(mix credo --strict --format=json)\"'"
      ]
    ]
  end

  # Copia el binario empaquetado a `~/bin`, sustituyendo lo que haya ahí.
  #
  # Esto sobrevive a los dos modos de fallo que dejaron un `alaja` de
  # 0 bytes — es decir, un CLI que salía sin imprimir nada y con exit 0,
  # indistinguible de un CLI sano:
  #
  #   1. Un symlink en el destino. `File.cp/2` lo sigue, así que copiar
  #      el binario recién construido sobre un enlace que apunta *de
  #      vuelta* a la salida del build trunca el origen antes de
  #      leerlo, devuelve `:ok` y deja el CLI muerto. Por eso
  #      `~/bin/alaja` terminó siendo un symlink a `./alaja` y cada
  #      `mix gen` posterior se autodestruía. Desenlazamos primero.
  #   2. Una salida de build vacía. Si `mix batamanta` falla a medias
  #      (cargo/zstd) puede dejar un `alaja` de 0 bytes; copiarlo
  #      instalaría un binario que sale con 0 sin hacer nada. Lo
  #      verificamos en el destino en vez de dar por buena la copia.
  defp install_binary(source_path, dest_path) do
    unlink_if_symlink(dest_path)

    case File.cp(source_path, dest_path) do
      :ok ->
        File.chmod!(dest_path, 0o755)
        size = File.stat!(dest_path).size

        if size == 0 do
          Mix.raise("[ERROR] El binario instalado en #{dest_path} quedo vacio (0 bytes)")
        end

        Mix.shell().info("  Batamanta instalado en #{dest_path} (#{size} bytes)")

      {:error, reason} ->
        Mix.shell().error("[ERROR] No se pudo copiar alaja: #{inspect(reason)}")
    end
  end

  # Sustituye un symlink del destino por un fichero real. `File.cp/2`
  # escribe *a través* de un symlink, así que sin esto el destino
  # heredado puede seguir apuntando al build (o a cualquier otro sitio)
  # en vez de contener la copia recién instalada.
  defp unlink_if_symlink(path) do
    case File.lstat(path) do
      {:ok, %File.Stat{type: :symlink}} -> File.rm(path)
      {:ok, _stat} -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> Mix.raise("[ERROR] No se pudo inspeccionar #{path}: #{inspect(reason)}")
    end
  end
end
