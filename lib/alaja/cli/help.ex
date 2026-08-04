defmodule Alaja.CLI.Help do
  @moduledoc """
  Help system for the Alaja CLI.

  Renders help output using Alaja's own components for visually rich,
  consistent terminal output.
  """

  alias Alaja.Components.{Header, Separator, Table}

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
    "ask" => Alaja.CLI.Commands.Show.Ask,
    "menu" => Alaja.CLI.Commands.Show.Menu,
    "yesno" => Alaja.CLI.Commands.Show.YesNo,
    "color" => Alaja.CLI.Commands.Color,
    "action" => Alaja.CLI.Commands.Action
  }

  # ---------------------------------------------------------------------------
  # Summary (alaja with no args)
  # ---------------------------------------------------------------------------

  @doc """
  Renders a compact summary of available commands.
  """
  @spec summary(map()) :: :ok
  def summary(descriptions) do
    Header.print("Alaja",
      subtitle: "Terminal UI & Process Orchestration Framework",
      size: :medium
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
      headers_color: :cyan,
      headers_effects: [:bold]
    )

    IO.puts("")

    Separator.print("QUICK REFERENCE", char: "━", width: 50, color: {0, 180, 216})

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
    Header.print("Alaja CLI", subtitle: "Complete command reference", size: :large)
    IO.puts("")

    global_options()
    IO.puts("")

    typed_messages_section()
    IO.puts("")

    display_commands_section()
    IO.puts("")

    interactive_commands_section()
    IO.puts("")

    color_command_section()
    IO.puts("")

    action_command_section()
    IO.puts("")

    theme_command_section()
    IO.puts("")

    Separator.print("MORE HELP", char: "━", width: 80, color: {0, 180, 216})

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
    Separator.print("GLOBAL OPTIONS", char: "━", width: 80, color: {0, 180, 216})
    IO.puts("")

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
      table_border: :none,
      padding: 0
    )
  end

  defp typed_messages_section do
    Separator.print("TYPED MESSAGES", char: "━", width: 80, color: {0, 180, 216})
    IO.puts("")

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
      table_border: :none,
      padding: 0
    )

    IO.puts("")
    IO.puts("  Usage: alaja <command> <text>")
    IO.puts("")
  end

  defp display_commands_section do
    Separator.print("DISPLAY COMMANDS", char: "━", width: 80, color: {0, 180, 216})
    IO.puts("")

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
      table_border: :none,
      padding: 0
    )
  end

  defp interactive_commands_section do
    Separator.print("INTERACTIVE COMMANDS", char: "━", width: 80, color: {0, 180, 216})
    IO.puts("")

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        ["ask", "Interactive text input"],
        ["menu", "Interactive selection menu"],
        ["yesno", "Interactive yes/no question"]
      ],
      table_border: :none,
      padding: 0
    )
  end

  defp color_command_section do
    Separator.print("COLOR COMMAND", char: "━", width: 80, color: {0, 180, 216})
    IO.puts("")

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
      table_border: :none,
      padding: 0
    )

    IO.puts("")

    IO.puts(
      "  Harmony types: triad, complementary, analogous, square, monochromatic, compound, split-complementary"
    )
  end

  defp action_command_section do
    Separator.print("ACTION COMMAND", char: "━", width: 80, color: {0, 180, 216})
    IO.puts("")

    Table.print(
      headers: ["Usage", "Description"],
      rows: [
        ["echo JSON | alaja action", "Execute from stdin pipe"],
        ["alaja action --file FILE", "Execute from JSON file"],
        ["alaja action --data JSON", "Execute from inline JSON"],
        ["alaja action --stdin", "Force stdin mode"]
      ],
      table_border: :none,
      padding: 0
    )
  end

  defp theme_command_section do
    Separator.print("THEME COMMAND", char: "━", width: 80, color: {0, 180, 216})
    IO.puts("")

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
      table_border: :none,
      padding: 0
    )
  end
end
