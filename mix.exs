defmodule Alaja.MixProject do
  use Mix.Project

  def project do
    [
      app: :alaja,
      version: "0.3.5",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Alaja",
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
      test_coverage: [tool: ExCoveralls],
      escript: [main_module: Alaja.CLI]
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

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/Lorenzo-SF/alaja",
      homepage_url: "https://github.com/Lorenzo-SF/alaja",
      extras: ["README.md", "README_ES.md", "LICENSE.md"],
      groups_for_modules: [
        "Core API": [Alaja],
        CLI: [
          Alaja.CLI,
          Alaja.CLI.Definition,
          Alaja.CLI.Dispatch,
          Alaja.CLI.Parser,
          Alaja.CLI.Help,
          Alaja.CLI.Validator,
          Alaja.CLI.GlobalOpts,
          Alaja.CLI.ErrorHandler
        ],
        "CLI Commands": [
          Alaja.CLI.Commands.Config,
          Alaja.CLI.Commands.Action,
          Alaja.CLI.Commands.Color,
          Alaja.CLI.Commands.Show,
          Alaja.CLI.Commands.Show.AnimatedBar,
          Alaja.CLI.Commands.Show.Ask,
          Alaja.CLI.Commands.Show.Bar,
          Alaja.CLI.Commands.Show.Breadcrumbs,
          Alaja.CLI.Commands.Show.Gradient,
          Alaja.CLI.Commands.Show.Header,
          Alaja.CLI.Commands.Show.Image,
          Alaja.CLI.Commands.Show.List,
          Alaja.CLI.Commands.Show.Menu,
          Alaja.CLI.Commands.Show.Message,
          Alaja.CLI.Commands.Show.Separator,
          Alaja.CLI.Commands.Show.Table,
          Alaja.CLI.Commands.Show.YesNo
        ],
        Components: [
          Alaja.Components.AnimatedBar,
          Alaja.Components.Bar,
          Alaja.Components.Box,
          Alaja.Components.Breadcrumbs,
          Alaja.Components.ColorWheel,
          Alaja.Components.Header,
          Alaja.Components.Json,
          Alaja.Components.Separator,
          Alaja.Components.Table
        ],
        Rendering: [
          Alaja.Printer,
          Alaja.Printer.Basics,
          Alaja.Printer.Interactive,
          Alaja.Buffer,
          Alaja.Cell
        ],
        "Syntax & Effects": [Alaja.Ansi],
        Structures: [
          Alaja.Structures.ChunkText,
          Alaja.Structures.EffectInfo,
          Alaja.Structures.MessageInfo
        ],
        Utilities: [
          Alaja.Config,
          Alaja.Helpers,
          Alaja.Terminal,
          Alaja.ImageRenderer,
          Alaja.ImageTerminal
        ]
      ],
      source_ref: "v0.1.0"
    ]
  end

  defp batamanta do
    [
      format: :escript,
      execution_mode: :cli,
      compression: 19,
      binary_name: "alaja"
    ]
  end

  defp deps do
    [
      {:pote, github: "Lorenzo-SF/pote", tag: "v0.2.0"},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:batamanta, "~> 1.5.1", optional: true, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer-ignore-warnings",
      plt_file: {:no_warn, "priv/plts/alaja"}
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
