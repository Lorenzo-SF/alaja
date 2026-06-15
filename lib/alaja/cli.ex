defmodule Alaja.CLI do
  @moduledoc """
  Entry point for the Alaja command-line interface.

  This module is defined using the `Alaja.CLI.Definition` DSL,
  making it self-hosted — the CLI is built with its own framework.

  ## Usage

      alaja [--help | -h]
      alaja [--version | -v]
      alaja <command> [args...]
      alaja <command> --help

  ## Available commands

  Run `alaja --help` for the full list.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  alias Alaja.CLI.Dispatch

  # ─── Typed messages (aliases of message) ─────────────────────────────────

  command("success", "Success message with green checkmark", run: {Dispatch, :success})

  command("error", "Error message with red cross", run: {Dispatch, :error})

  command("warning", "Warning message with yellow triangle", run: {Dispatch, :warning})

  command("info", "Info message with cyan indicator", run: {Dispatch, :info})

  command("debug", "Debug message with grey indicator", run: {Dispatch, :debug})

  command("notice", "Notice message with blue indicator", run: {Dispatch, :notice})

  command("critical", "Critical message with magenta indicator", run: {Dispatch, :critical})

  command("alert", "Alert message with red indicator", run: {Dispatch, :alert})

  command("emergency", "Emergency message with blinking indicator", run: {Dispatch, :emergency})

  command("happy", "Happy message with green indicator", run: {Dispatch, :happy})

  command("sad", "Sad message with blue indicator", run: {Dispatch, :sad})

  # ─── Display commands ────────────────────────────────────────────────────

  command("message", "Custom formatted message with full styling", run: {Dispatch, :message})

  command("header", "Styled header with optional subtitle", run: {Dispatch, :header})

  command("separator", "Horizontal divider line with optional text", run: {Dispatch, :separator})

  command("gradient", "Gradient-colored text (multi-color support)", run: {Dispatch, :gradient})

  command("table", "Rich tables with borders and per-cell styling", run: {Dispatch, :table})

  command("json", "Pretty-printed JSON with syntax highlighting", run: {Dispatch, :json})

  command("bar", "Progress bar with customizable appearance", run: {Dispatch, :bar})

  command("animated-bar", "Animated progress bar", run: {Dispatch, :animated_bar})

  command("breadcrumbs", "Navigation path display", run: {Dispatch, :breadcrumbs})

  command("animate", "Animated spinners and indicators", run: {Dispatch, :animate})

  command("pulsar", "Pulsar/radar animation with gradient wave effect", run: {Dispatch, :pulsar})

  command("image", "Render images (kitty/iterm2/sixel/ASCII)", run: {Dispatch, :image})

  command("list", "Styled list with optional header", run: {Dispatch, :list})

  command("ask", "Interactive text input", run: {Dispatch, :ask})

  command("menu", "Interactive selection menu", run: {Dispatch, :menu})

  command("yesno", "Interactive yes/no question", run: {Dispatch, :yesno})

  # ─── Other commands ──────────────────────────────────────────────────────

  command("color", "Color analysis, harmonies, conversions, and tone manipulation",
    run: {Dispatch, :color}
  )

  command("action", "Execute Alaja commands from JSON input", run: {Dispatch, :action})

  command("config", "Manage configuration and themes", run: {Dispatch, :config})
end
