defmodule Mix.Tasks.Alaja.Demo do
  @moduledoc """
  Render Alaja components in sequence for visual inspection.

  Usage:

      mix alaja.demo            # full gallery
      mix alaja.demo table      # one component
      mix alaja.demo all        # same as no args

  Components: messages, header, separator, gradient, table, json,
  bar, breadcrumbs, animate, list, color, action, scroll, tabs,
  log, progress, pulsar, animated-bar.

  Stateful and interactive components (scroll, tabs, log, progress,
  pulsar, animated-bar, ask, menu, yesno) require a TTY. In a pipe
  they print a one-line notice instead of running.

  ## Example

      $ mix alaja.demo header
      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ Alaja Header ━━
      ...

      $ mix alaja.demo pulsar
      [pulsing radar animation, ←→/q to quit]
  """
  @shortdoc "Render Alaja components for visual inspection"

  use Mix.Task

  alias Alaja.CLI.Pagination

  @components %{
    "messages" => :messages,
    "header" => :header,
    "separator" => :separator,
    "gradient" => :gradient,
    "table" => :table,
    "json" => :json,
    "bar" => :bar,
    "breadcrumbs" => :breadcrumbs,
    "animate" => :animate,
    "list" => :list,
    "log" => :log,
    "progress" => :progress,
    "pulsar" => :pulsar,
    "animated-bar" => :animated_bar,
    "color" => :color,
    "action" => :action,
    "ask" => :ask,
    "menu" => :menu,
    "yesno" => :yesno
  }

  # Order shown in `mix alaja.demo all`
  @gallery_order [
    :messages,
    :header,
    :separator,
    :gradient,
    :table,
    :json,
    :bar,
    :breadcrumbs,
    :animate,
    :list,
    :color,
    :action,
    :log,
    :progress,
    :pulsar,
    :animated_bar,
    :ask,
    :menu,
    :yesno
  ]

  @impl Mix.Task
  def run(args) do
    case args do
      [] ->
        run_all()

      ["all"] ->
        run_all()

      [name | _] when is_binary(name) ->
        if Map.has_key?(@components, name) do
          render_one(Map.fetch!(@components, name))
        else
          IO.puts(:stderr, "Unknown demo: #{name}")
          IO.puts(:stderr, "Available: #{Enum.join(Map.keys(@components) |> Enum.sort(), ", ")}")
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Public entry: full gallery
  # ---------------------------------------------------------------------------

  defp run_all do
    Alaja.print_info("alaja demo — component gallery (TTY=#{Pagination.tty?()})")

    for name <- @gallery_order do
      IO.puts("\n")
      render_one(name)
    end
  end

  # ---------------------------------------------------------------------------
  # Per-component renderer
  # ---------------------------------------------------------------------------

  defp render_one(:messages) do
    Alaja.CLI.Commands.Show.Message.run(["success", "Deploy completado"])
    Alaja.CLI.Commands.Show.Message.run(["error", "Build fallido"])
    Alaja.CLI.Commands.Show.Message.run(["warning", "Cuidado con X"])
    Alaja.CLI.Commands.Show.Message.run(["info", "Información útil"])
    Alaja.CLI.Commands.Show.Message.run(["debug", "Detalle de bajo nivel"])
    Alaja.CLI.Commands.Show.Message.run(["notice", "Aviso importante"])
    Alaja.CLI.Commands.Show.Message.run(["happy", "Todo va bien"])
  end

  defp render_one(:header) do
    Alaja.CLI.Commands.Show.Header.run(["Alaja Demo"])
  end

  defp render_one(:separator) do
    Alaja.CLI.Commands.Show.Separator.run(["Section divider"])
  end

  defp render_one(:gradient) do
    Alaja.CLI.Commands.Show.Gradient.run(["Alaja gradient demo", "--from", "red", "--to", "blue"])
  end

  defp render_one(:table) do
    Alaja.CLI.Commands.Show.Table.run([
      "--headers",
      "name,status,owner",
      "--rows",
      "api,ok,alice",
      "--rows",
      "web,degraded,bob",
      "--rows",
      "worker,ok,alice"
    ])
  end

  defp render_one(:json) do
    json = ~s({"name":"alaja","version":"3.0","features":["cli","tui","components"]})
    Alaja.CLI.Commands.Show.Json.run([json])
  end

  defp render_one(:bar) do
    Alaja.CLI.Commands.Show.Bar.run(["60", "--max", "100", "--label", "build"])
  end

  defp render_one(:breadcrumbs) do
    Alaja.CLI.Commands.Show.Breadcrumbs.run(["home", "lib", "alaja", "components"])
  end

  defp render_one(:animate) do
    Alaja.CLI.Commands.Show.Animate.run([])
  end

  defp render_one(:list) do
    Alaja.CLI.Commands.Show.List.run(["Fix deploy", "Write tests", "Update docs"])
  end

  defp render_one(:log) do
    run_stateful("log", fn ->
      Alaja.CLI.Commands.Show.Log.run([
        "Build started",
        "Compiling alaja 3.0",
        "Running 1068 tests",
        "All tests passed"
      ])
    end)
  end

  defp render_one(:progress) do
    run_stateful("progress", fn ->
      Alaja.CLI.Commands.Show.Progress.run([
        "--current",
        "75",
        "--total",
        "100",
        "--label",
        "build"
      ])
    end)
  end

  defp render_one(:pulsar) do
    run_stateful("pulsar", fn ->
      Alaja.CLI.Commands.Show.Pulsar.run(["Alaja", "--duration", "2000"])
    end)
  end

  defp render_one(:animated_bar) do
    run_stateful("animated-bar", fn ->
      Alaja.CLI.Commands.Show.AnimatedBar.run(["50", "--max", "100", "--duration", "1500"])
    end)
  end

  defp render_one(:color) do
    Alaja.CLI.Commands.Color.run(["#7aa2f7"])
  end

  defp render_one(:action) do
    Alaja.CLI.Commands.Action.run([
      "--data",
      ~s({"type":"success","text":"deploy completado"})
    ])
  end

  defp render_one(:ask) do
    run_interactive("ask", "alaja ask '¿Cuál es tu nombre?'")
  end

  defp render_one(:menu) do
    run_interactive("menu", "alaja menu 'Selecciona' 'opción A' 'opción B' 'opción C'")
  end

  defp render_one(:yesno) do
    run_interactive("yesno", "alaja yesno '¿Continuar?'")
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp run_stateful(name, fun) do
    if Pagination.tty?() do
      fun.()
    else
      IO.puts("(stateful demo '#{name}' requires a TTY — skipping)")
    end
  end

  defp run_interactive(name, hint) do
    if Pagination.tty?() do
      IO.puts("(interactive demo '#{name}' — run `#{hint}` to try it)")
    else
      IO.puts("(interactive demo '#{name}' requires a TTY — skipping)")
    end
  end
end
