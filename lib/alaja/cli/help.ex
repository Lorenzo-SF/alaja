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

    section_title("QUICK REFERENCE", @green)

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
  """
  @spec full() :: :ok
  def full do
    Header.print("Alaja CLI",
      subtitle: "Complete command reference",
      size: :large,
      color: @cyan,
      subtitle_color: {150, 150, 160}
    )

    IO.puts("")

    global_options()
    IO.puts("")

    typed_messages_section()
    IO.puts("")

    display_commands_section()
    IO.puts("")

    component_commands_section()
    IO.puts("")

    interactive_commands_section()
    IO.puts("")

    color_command_section()
    IO.puts("")

    action_command_section()
    IO.puts("")

    theme_command_section()
    IO.puts("")

    examples_section()
    IO.puts("")

    section_title("MORE HELP", @cyan)

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        ["alaja <cmd> --help", "Detailed help for any command"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
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

  defp global_options do
    section_title("GLOBAL OPTIONS", @cyan)

    Table.print(
      headers: ["Option", "Description"],
      rows: [
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
      table_border: :rounded,
      border_color: @cyan,
      headers_color: :cyan,
      headers_effects: [:bold],
      padding: 1
    )
  end

  defp typed_messages_section do
    section_title("TYPED MESSAGES", @green)

    Table.print(
      headers: ["Command", "Description"],
      rows: [
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
      table_border: :rounded,
      border_color: @green,
      headers_color: :green,
      headers_effects: [:bold],
      padding: 1
    )

    IO.puts("")
    IO.puts("  Usage: alaja <command> <text>")
    IO.puts("")
  end

  defp display_commands_section do
    section_title("DISPLAY COMMANDS", @magenta)

    Table.print(
      headers: ["Command", "Description"],
      rows: [
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
      table_border: :rounded,
      border_color: @magenta,
      headers_color: :magenta,
      headers_effects: [:bold],
      padding: 1
    )
  end

  defp component_commands_section do
    section_title("FASE-2 COMPONENTS", @blue)

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        ["scroll", "Stateful scrollable list with selection marker"],
        ["tabs", "Stateful tabbed interface with inverted active tab"],
        ["log", "Append-only log with retention limit"],
        ["progress", "Stateful progress bar (struct-based, CLI-renderable)"],
        ["pulsar", "Pulsar/radar animation with gradient wave effect"]
      ],
      table_border: :rounded,
      border_color: @blue,
      headers_color: :blue,
      headers_effects: [:bold],
      padding: 1
    )
  end

  defp interactive_commands_section do
    section_title("INTERACTIVE COMMANDS", @yellow)

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        ["ask", "Interactive text input"],
        ["menu", "Interactive selection menu"],
        ["yesno", "Interactive yes/no question"]
      ],
      table_border: :rounded,
      border_color: @yellow,
      headers_color: :yellow,
      headers_effects: [:bold],
      padding: 1
    )
  end

  defp color_command_section do
    section_title("COLOR COMMAND", @orange)

    Table.print(
      headers: ["Usage", "Description"],
      rows: [
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
      table_border: :rounded,
      border_color: @orange,
      headers_color: :yellow,
      headers_effects: [:bold],
      padding: 1
    )

    IO.puts("")

    IO.puts(
      "  Harmony types: triad, complementary, analogous, square, monochromatic, compound, split-complementary"
    )
  end

  defp action_command_section do
    section_title("ACTION COMMAND", @green)

    Table.print(
      headers: ["Usage", "Description"],
      rows: [
        ["echo JSON | alaja action", "Execute from stdin pipe"],
        ["alaja action --file FILE", "Execute from JSON file"],
        ["alaja action --data JSON", "Execute from inline JSON"],
        ["alaja action --stdin", "Force stdin mode"]
      ],
      table_border: :rounded,
      border_color: @green,
      headers_color: :green,
      headers_effects: [:bold],
      padding: 1
    )
  end

  defp theme_command_section do
    section_title("THEME COMMAND", @purple)

    Table.print(
      headers: ["Usage", "Description"],
      rows: [
        ["alaja theme init", "Install default themes to ~/.config/alaja/themes"],
        ["alaja theme list", "List available themes"],
        ["alaja theme set <name>", "Activate a theme"],
        ["alaja theme show <name>", "Show a single theme's colour table"],
        ["alaja theme show <name> <name> ...", "Show side-by-side comparison of given themes"],
        ["alaja theme show list", "Show side-by-side comparison of all themes"],
        ["alaja theme show all", "Show all themes sequentially"],
        ["alaja theme all", "Show side-by-side comparison of all themes"]
      ],
      table_border: :rounded,
      border_color: @purple,
      headers_color: :magenta,
      headers_effects: [:bold],
      padding: 1
    )
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
    {"Selectable list (FASE-2)", "alaja scroll a b c --select 1"},
    {"Tabs (FASE-2)", "alaja tabs dev staging prod --active 1"},
    {"Log with retention (FASE-2)", "alaja log \"line 1\" \"line 2\" --max-lines 5"},
    {"Stateful progress (FASE-2)", "alaja progress --current 75 --total 100 --label build"},
    {"Breadcrumbs", "alaja breadcrumbs home lib alaja --current alaja"},
    {"Bullet list", "alaja list \"fix deploy\" \"write tests\" --header \"To do\" --color cyan"},
    {"Radar animation (3s)", "alaja pulsar \"Alaja\" --duration 3000"},
    {"Color harmonies", "alaja color red --harmony triad"},
    {"Batch from stdin", "echo '{\"type\":\"success\",\"text\":\"ok\"}' | alaja action"}
  ]

  defp examples_section do
    section_title("EXAMPLES", @orange)

    IO.puts("")

    Enum.each(@examples, fn {comment, command} ->
      IO.puts([fg_color(@cyan), ANSI.bright(), "# ", comment, ANSI.reset()])
      IO.puts([fg_color({180, 220, 120}), "  ", command, ANSI.reset()])
      IO.puts("")
    end)
  end

  defp section_title(title, color) do
    Separator.print(title, char: "━", width: @section_width, color: color)
    IO.puts("")
  end

  defp fg_color({r, g, b}), do: "\e[38;2;#{r};#{g};#{b}m"
end
