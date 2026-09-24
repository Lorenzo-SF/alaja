defmodule Alaja.MixProject do
  use Mix.Project

  def project do
    [
      app: :alaja,
      version: "3.1.2",
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
        "Core API": [Alaja, Alaja.App, Alaja.Cmd, Alaja.Sub, Alaja.Msg],
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
          Alaja.CLI.Commands.Config,
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
          Alaja.Ansi,
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
      source_ref: "3.1.2"
    ]
  end

  defp batamanta do
    [
      format: :release,
      execution_mode: :cli,
      compression: 19,
      binary_name: "alaja",
      show_banner: true
    ]
  end

  defp deps do
    [
      {:pote, "~> 3.0", override: true},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:batamanta, "~> 3.0.0", optional: true, runtime: false},
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
        dest_dir = Path.expand("~/bin")
        File.mkdir_p!(dest_dir)
        config = Mix.Project.config()
        app_name = Atom.to_string(config[:app])

        source_path = Path.expand("alaja")
        dest_path = Path.join(dest_dir, app_name)

        if File.exists?(source_path) do
          case File.cp(source_path, dest_path) do
            :ok ->
              File.chmod!(dest_path, 0o755)
              Mix.shell().info("  Batamanta instalado en #{dest_path}")

            {:error, reason} ->
              Mix.shell().error("[ERROR] No se pudo copiar alaja: #{inspect(reason)}")
          end
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
end
