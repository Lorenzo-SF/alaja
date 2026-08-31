defmodule Alaja.CLI.Help do
  @moduledoc """
  Help system for the Alaja CLI.

  Two surfaces:

    * `summary/1` — compact one-screen catalog shown after the startup
      showcase (or printed directly when the user runs `alaja` with no
      args on a non-TTY).
    * `full/1`    — the complete reference, grouped into navigable tabs
      on a TTY (`←`/`→` to switch) or rendered sequentially when piped.

  The CLI is split in two layers:

    * **Display** — stateless, fire-and-forget renderers
      (`message`, `header`, `separator`, `gradient`, `table`, `json`,
      `bar`, `breadcrumbs`, `animate`, `list`, `image`).
    * **Stateful** — components with internal state that update in
      place (`pulsar`, `animated-bar`).
    * **Interactive** — components that read input from the user
      (`ask`, `menu`, `yesno`).

  Every component is a real Elixir module under
  `Alaja.Components.*`; the CLI command is a thin wrapper that parses
  argv and delegates. See `mix alaja.demo` for an interactive gallery.
  """

  alias Alaja.Components.{Header, Separator, Table}
  alias IO.ANSI

  # All direct commands mapped to their help module. Theme is the only
  # command with a sub-action DSL (init / set / list / show / all) — its
  # help is rendered by its own `@help_data` via HelpFormatter.
  @commands %{
    "message" => Alaja.CLI.Commands.Show.Message,
    "header" => Alaja.CLI.Commands.Show.Header,
    "separator" => Alaja.CLI.Commands.Show.Separator,
    "gradient" => Alaja.CLI.Commands.Show.Gradient,
    "table" => Alaja.CLI.Commands.Show.Table,
    "json" => Alaja.CLI.Commands.Show.Json,
    "bar" => Alaja.CLI.Commands.Show.Bar,
    "animated-bar" => Alaja.CLI.Commands.Show.AnimatedBar,
    "breadcrumbs" => Alaja.CLI.Commands.Show.Breadcrumbs,
    "animate" => Alaja.CLI.Commands.Show.Animate,
    "image" => Alaja.CLI.Commands.Show.Image,
    "list" => Alaja.CLI.Commands.Show.List,
    "pulsar" => Alaja.CLI.Commands.Show.Pulsar,
    "ask" => Alaja.CLI.Commands.Show.Ask,
    "menu" => Alaja.CLI.Commands.Show.Menu,
    "yesno" => Alaja.CLI.Commands.Show.YesNo,
    "color" => Alaja.CLI.Commands.Color,
    "action" => Alaja.CLI.Commands.Action
  }

  # Accent colors per section (24-bit RGB)
  @cyan {0, 180, 216}
  @green {80, 220, 120}
  @magenta {255, 120, 200}
  @yellow {255, 200, 80}
  @blue {100, 150, 255}
  @orange {255, 160, 60}
  @purple {180, 130, 255}

  @section_width 80

  # ---------------------------------------------------------------------------
  # Summary (alaja with no args → shown after the showcase, when TTY)
  # ---------------------------------------------------------------------------

  @doc """
  Renders a compact summary of available commands plus a quick-start
  cookbook of the most useful one-liners.

  Used both as the "what can I do here?" landing screen on first launch
  and as the fallback when running `alaja` on a non-TTY.
  """
  @spec summary(map()) :: :ok
  def summary(descriptions) do
    Header.print("Alaja",
      subtitle: "Terminal UI & Process Orchestration Framework",
      size: :medium,
      color: @cyan,
      subtitle_color: {150, 150, 160}
    )

    IO.puts("")

    rows =
      Enum.map(descriptions, fn {cmd, desc} ->
        [cmd, desc]
      end)

    Table.print(
      headers: ["Command", "Description"],
      rows: rows,
      table_border: :rounded,
      border_color: @cyan,
      headers_color: :cyan,
      headers_effects: [:bold]
    )

    IO.puts("")

    IO.write(section_title_text("QUICK START", @green))

    quick_start_text()

    IO.puts("")
    :ok
  end

  # The six one-liners that pay for the entire CLI. Kept short so the
  # summary stays one screen tall even on a 24-line terminal.
  @quick_start [
    {"Status message", "alaja success \"Deploy completado\""},
    {"Quick header", "alaja header \"Release 3.0\" --subtitle \"ready for review\""},
    {"Inline table", "alaja table --headers name;status --rows \"api;OK\" \"db;WARN\""},
    {"Pipe JSON", "cat stats.json | alaja json"},
    {"Theme picker", "alaja theme set dracula"},
    {"Multi-step from JSON", "alaja action --file pipeline.json"}
  ]

  defp quick_start_text do
    Enum.each(@quick_start, fn {comment, cmd} ->
      IO.puts([
        fg_color(@cyan),
        ANSI.bright(),
        "# ",
        comment,
        ANSI.reset(),
        "\n",
        fg_color({180, 220, 120}),
        "  ",
        cmd,
        ANSI.reset(),
        "\n"
      ])
    end)
  end

  # ---------------------------------------------------------------------------
  # Full help (alaja --help)
  # ---------------------------------------------------------------------------

  @doc """
  Renders the complete help for all commands.

  On an interactive terminal the sections are grouped into tabs
  (Overview / Display / Stateful / Interactive / Color / Action /
  Theme / Cookbook); when piped or redirected everything renders
  sequentially. `descriptions` (the host command list) is shown inside
  the Overview tab on a TTY and is printed separately by the caller
  (`summary/1`) otherwise.
  """
  @spec full(list() | keyword()) :: :ok
  def full(descriptions \\ []) do
    if Alaja.CLI.HelpTabs.interactive?() do
      # Header is painted by HelpTabs inside the alternate screen so it
      # stays anchored at the top of the scroll region. We do not paint
      # it here — otherwise it would appear twice (once in the user's
      # terminal, once inside the alt screen).
      Alaja.CLI.HelpTabs.run(build_panels(descriptions), %Alaja.CLI.GlobalOpts{})
    else
      Header.print("Alaja CLI",
        subtitle: "Complete command reference",
        size: :large,
        color: @cyan,
        subtitle_color: {150, 150, 160}
      )

      flat_full(descriptions)
    end

    :ok
  end

  defp flat_full(descriptions) do
    IO.write([
      "\n",
      global_options_text(),
      "\n",
      typed_messages_text(),
      "\n",
      display_commands_text(),
      "\n",
      component_commands_text(),
      "\n",
      interactive_commands_text(),
      "\n",
      color_command_text(),
      "\n",
      action_command_text(),
      "\n",
      cookbook_text(),
      "\n",
      more_help_text(),
      "\n"
    ])

    if descriptions != [] do
      IO.write(["\n", host_commands_text(descriptions), "\n"])
    end

    :ok
  end

  defp build_panels(descriptions) do
    base = [
      {"Overview", panel_text([global_options_text(), "\n", typed_messages_text()])},
      {"Display", panel_text([display_commands_text()])},
      {"Stateful", panel_text([component_commands_text()])},
      {"Interactive", panel_text([interactive_commands_text()])},
      {"Color", panel_text([color_command_text()])},
      {"Action", panel_text([action_command_text()])},
      {"Theme", panel_text([theme_command_text()])},
      {"Cookbook", panel_text([cookbook_text()])}
    ]

    base =
      if descriptions != [] do
        base ++ [{"Host", panel_text([host_commands_text(descriptions)])}]
      else
        base
      end

    Enum.map(base, fn {label, text} -> %{label: label, render: fn -> text end} end)
  end

  defp panel_text(iodata), do: IO.iodata_to_binary(iodata)

  # ---------------------------------------------------------------------------
  # Command-specific help
  # ---------------------------------------------------------------------------

  @doc """
  Renders help for a specific command by delegating to the command module.
  """
  @spec command(String.t()) :: :ok | {:error, :not_found}
  def command(cmd) do
    case Map.fetch(@commands, cmd) do
      {:ok, module} ->
        if function_exported?(module, :help, 1),
          do: module.help(%Alaja.CLI.GlobalOpts{}),
          else: :ok

      :error ->
        # Theme has its own help via HelpFormatter + global arg
        if cmd == "theme" do
          Alaja.CLI.Commands.Theme.help(%Alaja.CLI.GlobalOpts{})
        else
          IO.puts(:stderr, "Unknown command: '#{cmd}'")
          {:error, :not_found}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Sections
  # ---------------------------------------------------------------------------

  defp global_options_text do
    [
      section_title_text("GLOBAL OPTIONS", @cyan),
      global_options_table_text()
    ]
  end

  defp global_options_table_text do
    table_text(
      ["Option", "Description"],
      [
        ["--help, -h", "Show this help"],
        ["--version, -v", "Print version"],
        ["--raw", "Raw positioning mode (message/header/bar/gradient/color)"],
        ["--pos-x N", "X coordinate with --raw"],
        ["--pos-y N", "Y coordinate with --raw"],
        ["--align TYPE", "Alignment: left, center, right"],
        ["--box", "Wrap output in a bordered box (display commands)"],
        ["--box-title TEXT", "Box title (with --box)"],
        ["--box-border TYPE", "Box border style (with --box)"],
        ["--box-color COLOR", "Box border color (with --box)"],
        ["--bg-color COLOR", "Background color for the output (any display command)"],
        ["--no-color", "Disable ANSI output (respects NO_COLOR)"],
        ["--verbose", "Output raw ANSI instead of rendering"],
        ["--quiet, -q", "Suppress output"],
        ["--stdin", "Read JSON from stdin (action)"]
      ],
      @cyan
    )
  end

  defp typed_messages_text do
    [
      section_title_text("TYPED MESSAGES", @green),
      table_text(
        ["Command", "Description"],
        [
          ["success", "Success message with green checkmark"],
          ["error", "Error message with red cross"],
          ["warning", "Warning message with yellow triangle"],
          ["info", "Info message with cyan indicator"],
          ["debug", "Debug message with grey indicator"],
          ["notice", "Notice message with blue indicator"],
          ["critical", "Critical message with magenta indicator"],
          ["alert", "Alert message with red indicator"],
          ["emergency", "Emergency message with blinking indicator"],
          ["happy", "Happy message with green indicator"],
          ["sad", "Sad message with blue indicator"]
        ],
        @green
      ),
      "\n",
      "  Usage: alaja <command> <text>  (use --align center|right to align)",
      "\n"
    ]
  end

  defp display_commands_text do
    [
      section_title_text("DISPLAY COMMANDS", @magenta),
      table_text(
        ["Command", "Description"],
        [
          ["message", "Custom formatted message with full styling (chunks, colors, effects)"],
          ["header", "Styled header with optional subtitle"],
          ["separator", "Horizontal divider line with optional text"],
          ["gradient", "Gradient-colored text (multi-color support)"],
          ["table", "Rich tables with borders and per-cell styling"],
          ["json", "Pretty-printed JSON with syntax highlighting"],
          ["bar", "Progress bar with customizable appearance"],
          ["animated-bar", "Animated progress bar (spinner/kitt/pulse/wave/rainbow)"],
          ["breadcrumbs", "Navigation path display"],
          ["animate", "Animated spinners and indicators"],
          ["image", "Render images (kitty/iterm2/sixel/ASCII fallback)"],
          ["list", "Styled list with optional header"]
        ],
        @magenta
      ),
      "\n",
      "  Run alaja <command> --help for the full option list.",
      "\n"
    ]
  end

  defp component_commands_text do
    [
      section_title_text("STATEFUL COMPONENTS", @blue),
      table_text(
        ["Command", "Description"],
        [
          ["pulsar", "Pulsar/radar animation with gradient wave effect"],
          ["animated-bar", "Animated bar with --duration / --max-iterations"]
        ],
        @blue
      ),
      "\n",
      "  Stateful components keep a struct in memory and re-render in place.",
      "\n"
    ]
  end

  defp interactive_commands_text do
    [
      section_title_text("INTERACTIVE COMMANDS", @yellow),
      table_text(
        ["Command", "Description"],
        [
          ["ask", "Interactive text input (e.g. `alaja ask \"Name?\"`)"],
          ["menu", "Interactive selection menu (`alaja menu \"Pick\" A B C`)"],
          ["yesno", "Interactive yes/no question (`alaja yesno \"Continue?\"`)"]
        ],
        @yellow
      ),
      "\n",
      "  Interactive commands require a TTY. They are no-ops on a pipe.",
      "\n"
    ]
  end

  defp color_command_text do
    [
      section_title_text("COLOR COMMAND", @orange),
      table_text(
        ["Usage", "Description"],
        [
          ["alaja color <color>", "Show color info in all formats"],
          ["alaja color <color> --harmony TYPE", "Generate color harmonies"],
          ["alaja color <c> --darken N", "Darken by N steps"],
          ["alaja color <c> --lighten N", "Lighten by N steps"],
          ["alaja color <c> --lab", "Include CIELAB values"],
          ["alaja color <c> --xyz", "Include CIE XYZ values"],
          ["alaja color <c> --kelvin", "Include color temperature (K)"],
          ["alaja color <c> --pantone", "Include Pantone approximation"],
          ["alaja color <c> --contrast COLOR", "WCAG contrast ratio and Delta E"]
        ],
        @orange,
        headers_color: :yellow
      ),
      "\n",
      "  Harmony types: triad, complementary, analogous, square, monochromatic, compound, split-complementary",
      "  Color formats: hex:#RRGGBB, rgb:R;G;B, hsl:H;S;L, hsv:H;S;V, cmyk:C;M;Y;K, xterm:N, theme:<key>",
      "\n"
    ]
  end

  defp action_command_text do
    [
      section_title_text("ACTION COMMAND", @green),
      table_text(
        ["Usage", "Description"],
        [
          ["echo JSON | alaja action", "Execute from stdin pipe"],
          ["alaja action --file FILE", "Execute from JSON file"],
          ["alaja action --data JSON", "Execute from inline JSON"],
          ["alaja action --data BATCH --parallel 4", "Run actions concurrently"],
          ["alaja action --data BATCH --stop-on-error", "Halt on first failure"],
          ["alaja action --data BATCH --dry-run", "Print what would run"]
        ],
        @green
      ),
      "\n",
      "  Action JSON shape: {\"command\":\"<cmd>\", \"args\":[\"...\"]} or {\"actions\":[...]}",
      "\n"
    ]
  end

  defp theme_command_text do
    [
      section_title_text("THEME COMMAND", @purple),
      table_text(
        ["Usage", "Description"],
        [
          ["alaja theme init", "Install default themes to ~/.config/alaja/themes"],
          ["alaja theme list", "List available themes"],
          ["alaja theme set <name>", "Activate a theme (persisted)"],
          ["alaja theme show <name>", "Show a single theme's colour table"],
          ["alaja theme show <name> <name>...", "Show side-by-side comparison"],
          ["alaja theme show list", "Compare all themes side-by-side"],
          ["alaja theme show all", "Show all themes sequentially"]
        ],
        @purple,
        headers_color: :magenta
      ),
      "\n",
      "  Theme colours are referenced from components as \"theme:<key>\".",
      "\n"
    ]
  end

  # ---------------------------------------------------------------------------
  # Cookbook — copy-pasteable recipes grouped by use case
  # ---------------------------------------------------------------------------

  defp cookbook_text do
    [
      section_title_text("COOKBOOK — copy-pasteable recipes", @orange),
      "\n",
      cookbook_examples_text()
    ]
  end

  # Each recipe is a tuple {use-case, comment, command}. Comments are
  # short so the cookbook fits one screen on a TTY. Commands have been
  # validated against the actual switches exposed by each command.
  @cookbook [
    # ── Status / feedback ────────────────────────────────────────────────
    {"status", "Pipeline status (CI logs, scripts)",
     "alaja success \"deploy: v3.0.4 rolled out\""},
    {"status", "Fail loudly in scripts", "alaja error \"postgres connection refused\""},
    {"status", "Caution without alarm",
     "alaja warning \"deprecated: --legacy flag, remove in 4.0\""},
    # ── Headers / structure ──────────────────────────────────────────────
    {"structure", "Section divider with title",
     "alaja separator \"Pipeline\" --width 60 --color hex:00ffff"},
    {"structure", "Big release banner",
     "alaja header \"v3.0\" --subtitle \"Terminal UI framework\" --size large"},
    {"structure", "Breadcrumbs for nav", "alaja breadcrumbs home users alice --current alice"},
    # ── Tables / data ────────────────────────────────────────────────────
    {"data", "Service health table",
     "alaja table --headers service;status;uptime --rows \"api;OK;12d;;db;WARN;2h\""},
    {"data", "JSON pretty-printer (file or stdin)", "cat config.json | alaja json --indent 2"},
    {"data", "Bullet list with header",
     "alaja list --header \"TODO\" \"fix deploy\" \"write tests\" \"update docs\""},
    # ── Progress / streaming ─────────────────────────────────────────────
    {"progress", "One-shot progress bar", "alaja bar 60 --max 100 --label build --filled-char █"},
    {"progress", "Animated bar (2s demo)",
     "alaja animated-bar 50 --max 100 --duration 2000 --type kitt"},
    # ── Color / styling ──────────────────────────────────────────────────
    {"style", "Gradient title", "alaja gradient \"alaja 3.0\" --from hex:ff6b6b --to hex:4ecdc4"},
    {"style", "Bordered callout",
     "alaja warning \"production deploy in 5m\" --box --box-title DEPLOY"},
    {"style", "Centered message", "alaja success \"Done\" --align center"},
    # ── Color analysis ───────────────────────────────────────────────────
    {"analysis", "Generate harmonies", "alaja color hex:ff6b6b --harmony triad"},
    {"analysis", "WCAG contrast check", "alaja color hex:1e1e2e --contrast hex:cdd6f4"},
    # ── Images ───────────────────────────────────────────────────────────
    {"images", "Render a logo", "alaja image --path logo.png --width 40"},
    {"images", "ASCII fallback when no graphics protocol",
     "alaja image --path photo.jpg --to-ascii-art --ascii-style detailed"},
    # ── Themes ───────────────────────────────────────────────────────────
    {"themes", "Install and activate", "alaja theme init && alaja theme set dracula"},
    {"themes", "Compare two themes", "alaja theme show dracula nord"},
    # ── Batch / automation ───────────────────────────────────────────────
    {"batch", "Single action from stdin",
     "echo '{\"command\":\"success\",\"args\":[\"Done!\"]}' | alaja action"},
    {"batch", "Multi-action with stop-on-error",
     "alaja action --file pipeline.json --stop-on-error"},
    {"batch", "Parallel actions", "alaja action --file pipeline.json --parallel 4"}
  ]

  defp cookbook_examples_text do
    Enum.flat_map(@cookbook, fn {group, comment, cmd} ->
      [
        fg_color(@cyan),
        ANSI.bright(),
        "# ",
        group,
        " · ",
        comment,
        ANSI.reset(),
        "\n",
        fg_color({180, 220, 120}),
        "  ",
        cmd,
        ANSI.reset(),
        "\n"
      ]
    end)
  end

  # ---------------------------------------------------------------------------
  # Footer
  # ---------------------------------------------------------------------------

  defp more_help_text do
    [
      section_title_text("MORE HELP", @cyan),
      table_text(
        ["Command", "Description"],
        [
          ["alaja <cmd> --help", "Detailed help for any command (incl. options + examples)"],
          ["mix alaja.demo [component]", "Render every component for visual inspection"]
        ],
        @cyan,
        table_border: :none
      )
    ]
  end

  defp host_commands_text(descriptions) do
    rows = Enum.map(descriptions, fn {cmd, desc} -> [cmd, desc] end)

    [
      section_title_text("COMMAND LIST", @green),
      table_text(["Command", "Description"], rows, @green)
    ]
  end

  # ---------------------------------------------------------------------------
  # Section builders
  # ---------------------------------------------------------------------------

  defp table_text(headers, rows, color, opts \\ []) do
    Table.render(
      headers: headers,
      rows: rows,
      table_border: Keyword.get(opts, :table_border, :rounded),
      border_color: color,
      headers_color: Keyword.get(opts, :headers_color, color),
      headers_effects: [:bold],
      padding: 1
    )
    |> Alaja.Buffer.to_iodata()
    |> IO.iodata_to_binary()
    |> Kernel.<>("\n")
  end

  defp section_title_text(title, color) do
    separator =
      Separator.render(title, char: "━", width: @section_width, color: color)
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()

    [separator, "\n"]
  end

  defp fg_color({r, g, b}), do: "\e[38;2;#{r};#{g};#{b}m"
end
