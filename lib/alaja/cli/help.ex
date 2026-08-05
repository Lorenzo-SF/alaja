defmodule Alaja.CLI.Help do
  @moduledoc """
  Help system for the Alaja CLI.

  Renders help output using Alaja's own components for visually rich,
  consistent terminal output. Every section gets its own accent color
  and bordered tables, and the full help ends with a worked examples
  section so users can copy-paste real commands.
  """

  alias Alaja.Components.{Header, Separator, Table}
  alias IO.ANSI

  # All direct commands mapped to their help module
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
    "scroll" => Alaja.CLI.Commands.Show.Scroll,
    "tabs" => Alaja.CLI.Commands.Show.Tabs,
    "log" => Alaja.CLI.Commands.Show.Log,
    "progress" => Alaja.CLI.Commands.Show.Progress,
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
  Renders a compact summary of available commands.
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

    IO.write(section_title_text("QUICK REFERENCE", @green))

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        ["alaja --help", "Full reference for all commands"],
        ["alaja <cmd> --help", "Command-specific help"],
        ["alaja --version", "Print version"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
  end

  # ---------------------------------------------------------------------------
  # Full help (alaja --help)
  # ---------------------------------------------------------------------------

  @doc """
  Renders the complete help for all commands.

  On an interactive terminal the sections are grouped into three tabs
  (Overview / Commands / Examples); when piped or redirected everything
  renders sequentially. `descriptions` (the host command list) is shown
  inside the Commands tab on a TTY and is printed separately by the
  caller (`summary/1`) otherwise.
  """
  @spec full(list() | keyword()) :: :ok
  def full(descriptions \\ []) do
    Header.print("Alaja CLI",
      subtitle: "Complete command reference",
      size: :large,
      color: @cyan,
      subtitle_color: {150, 150, 160}
    )

    if Alaja.CLI.HelpTabs.interactive?() do
      IO.write("\r\n")
      Alaja.CLI.HelpTabs.run(build_panels(descriptions), %Alaja.CLI.GlobalOpts{})
    else
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
      theme_command_text(),
      "\n",
      examples_text(),
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
    overview = IO.iodata_to_binary([global_options_text(), "\n", typed_messages_text()])

    commands =
      IO.iodata_to_binary([
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
        theme_command_text(),
        if(descriptions != [], do: ["\n", host_commands_text(descriptions)])
      ])

    examples = IO.iodata_to_binary([examples_text(), "\n", more_help_text()])

    [
      {"Overview", overview},
      {"Commands", commands},
      {"Examples", examples}
    ]
    |> Enum.map(fn {label, text} -> %{label: label, render: fn -> text end} end)
  end

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
        if function_exported?(module, :help, 0), do: module.help(), else: :ok

      :error ->
        IO.puts(:stderr, "Unknown command: '#{cmd}'")
        {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Sections
  # ---------------------------------------------------------------------------

  defp global_options_text do
    [section_title_text("GLOBAL OPTIONS", @cyan), global_options_table_text()]
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
      "  Usage: alaja <command> <text>",
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
          ["animated-bar", "Animated progress bar"],
          ["breadcrumbs", "Navigation path display"],
          ["animate", "Animated spinners and indicators"],
          ["image", "Render images (kitty/iterm2/sixel/ASCII fallback)"],
          ["list", "Styled list with optional header"]
        ],
        @magenta
      )
    ]
  end

  defp component_commands_text do
    [
      section_title_text("STATEFUL COMPONENTS", @blue),
      table_text(
        ["Command", "Description"],
        [
          ["scroll", "Stateful scrollable list with selection marker"],
          ["tabs", "Stateful tabbed interface with inverted active tab"],
          ["log", "Append-only log with retention limit"],
          ["progress", "Stateful progress bar (struct-based, CLI-renderable)"],
          ["pulsar", "Pulsar/radar animation with gradient wave effect"]
        ],
        @blue
      )
    ]
  end

  defp interactive_commands_text do
    [
      section_title_text("INTERACTIVE COMMANDS", @yellow),
      table_text(
        ["Command", "Description"],
        [
          ["ask", "Interactive text input"],
          ["menu", "Interactive selection menu"],
          ["yesno", "Interactive yes/no question"]
        ],
        @yellow
      )
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
          ["alaja action --stdin", "Force stdin mode"]
        ],
        @green
      )
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
          ["alaja theme set <name>", "Activate a theme"],
          ["alaja theme show <name>", "Show a single theme's colour table"],
          ["alaja theme show <name> <name> ...", "Show side-by-side comparison of given themes"],
          ["alaja theme show list", "Show side-by-side comparison of all themes"],
          ["alaja theme show all", "Show all themes sequentially"],
          ["alaja theme all", "Show side-by-side comparison of all themes"]
        ],
        @purple,
        headers_color: :magenta
      )
    ]
  end

  @examples [
    {"Success message in green", "alaja success \"Deploy completado\""},
    {"Error message in red", "alaja error \"Build fallido\""},
    {"Big header with subtitle", "alaja header \"Alaja 3.0\" --subtitle \"Terminal UI framework\""},
    {"Divider with title", "alaja separator \"Deploy\" --width 60 --color cyan"},
    {"Gradient text", "alaja gradient \"hola mundo\" --from red --to blue"},
    {"Table with borders", "alaja table --headers name,status --rows \"api,ok\" \"web,ok\""},
    {"Pretty-printed JSON", "echo '{\"name\":\"alaja\",\"v\":3}' | alaja json"},
    {"Progress bar with label", "alaja bar 60 --max 100 --label build --filled-char █"},
    {"Animated progress (2s)", "alaja animated-bar 50 --max 100 --duration 2000"},
    {"Selectable list", "alaja scroll a b c --select 1"},
    {"Tabs", "alaja tabs dev staging prod --active 1"},
    {"Log with retention", "alaja log \"line 1\" \"line 2\" --max-lines 5"},
    {"Stateful progress", "alaja progress --current 75 --total 100 --label build"},
    {"Breadcrumbs", "alaja breadcrumbs home lib alaja --current alaja"},
    {"Bullet list", "alaja list \"fix deploy\" \"write tests\" --header \"To do\" --color cyan"},
    {"Radar animation (3s)", "alaja pulsar \"Alaja\" --duration 3000"},
    {"Color harmonies", "alaja color red --harmony triad"},
    {"Batch from stdin", "echo '{\"type\":\"success\",\"text\":\"ok\"}' | alaja action"}
  ]

  defp examples_text do
    pairs =
      Enum.map(@examples, fn {comment, command} ->
        [fg_color(@cyan), ANSI.bright(), "# ", comment, ANSI.reset(), "\n",
         fg_color({180, 220, 120}), "  ", command, ANSI.reset(), "\n"]
      end)

    [section_title_text("EXAMPLES", @orange), "\n", pairs]
  end

  defp more_help_text do
    [
      section_title_text("MORE HELP", @cyan),
      table_text(
        ["Command", "Description"],
        [["alaja <cmd> --help", "Detailed help for any command"]],
        @cyan,
        table_border: :none
      )
    ]
  end

  defp host_commands_text(descriptions) do
    rows = Enum.map(descriptions, fn {cmd, desc} -> [cmd, desc] end)

    [section_title_text("COMMAND LIST", @green), table_text(["Command", "Description"], rows, @green)]
  end

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
