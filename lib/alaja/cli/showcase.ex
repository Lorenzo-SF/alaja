defmodule Alaja.CLI.Showcase do
  @moduledoc """
  Startup "business card" for `alaja` with no arguments.

  Draws a short self-demo: a header, a few FASE-2 components and display
  commands positioned in raw mode, and a pulsing radar in the center that
  runs for ~3.5s. The screen is then cleared and the caller prints the
  regular full help, so the showcase never gets in the way of a script.

  Only runs when stdout is an interactive TTY (pipes, redirects and tests
  get plain help immediately) and can be disabled with
  `ALAJ: NO_SHOWCASE=1`.
  """

  alias Alaja.Components
  alias Alaja.ANSI
  alias Alaja.CLI.ViewText
  alias Alaja.Printer.RawPrinter

  @pulsar_width 46
  @pulsar_height 9
  @pulsar_ms 3500
  @pulsar_speed 60

  @doc """
  Runs the showcase when the terminal is interactive; no-op otherwise.
  """
  @spec maybe_run() :: :ok
  def maybe_run do
    cond do
      not IO.ANSI.enabled?() ->
        :ok

      System.get_env("ALAJ: NO_SHOWCASE") in ["1", "true", "yes"] ->
        :ok

      true ->
        run()
    end
  end

  @doc "Runs the full showcase animation (blocking ~3.5s)."
  @spec run() :: :ok
  def run do
    {cols, rows} = terminal_size()

    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.hide_cursor()])

    draw_header(cols)
    draw_components(cols)
    draw_pulsar(cols, rows)

    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.show_cursor()])
    :ok
  end

  defp draw_header(cols) do
    width = min(cols, 72)
    x = max(div(cols - width, 2), 1)

    header =
      Components.Header.render("Alaja",
        subtitle: "Terminal UI & Process Orchestration Framework",
        size: :large,
        color: {0, 180, 216},
        subtitle_color: {150, 150, 160},
        width: width
      )
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()

    RawPrinter.print_at_raw(header, {x, 1}, :none)

    separator =
      Components.Separator.render("C A R T A   D E   P R E S E N T A C I Ó N", char: "━", width: width, color: {255, 160, 60})
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()

    RawPrinter.print_at_raw(separator, {x, 6}, :none)
  end

  defp draw_components(cols) do
    left_x = max(4, div(cols, 8))
    right_x = max(div(cols, 2), 44)

    # Left column: scrollable list + log
    list =
      Components.list_view(%Components.ListState{
        items: ["alaja header", "alaja table", "alaja gradient", "alaja json", "alaja pulsar"],
        selected: 2,
        offset: 0,
        max_visible: 10
      })

    RawPrinter.print_at_raw(render_text(list), {left_x, 8}, :none)

    log =
      Components.log_view(%Components.LogState{
        lines: ["✓ componentes FASE-2", "✓ 1032 tests verdes", "✓ escript con ERTS embebido"],
        max_lines: 10
      })

    RawPrinter.print_at_raw(render_text(log), {left_x, 15}, :none)

    # Right column: tabs + progress
    tabs =
      Components.tabs_view(%Components.TabsState{
        labels: ["terminal", "raw", "box", "theme"],
        active: 1
      })

    RawPrinter.print_at_raw(render_text(tabs), {right_x, 8}, :none)

    progress =
      Components.progress_view(%Components.ProgressState{
        current: 65,
        total: 100,
        width: 26,
        label: "ready"
      })

    RawPrinter.print_at_raw(render_text(progress), {right_x, 11}, :none)

    tip =
      render_text(
        Alaja.View.Node.text("alaja --help · alaja <cmd> --help · alaja --version",
          style: [:dim]
        )
      )

    RawPrinter.print_at_raw(tip, {max(4, div(cols, 8)), 22}, :none)
  end

  defp render_text(node), do: node |> ViewText.render() |> IO.iodata_to_binary()

  defp draw_pulsar(cols, rows) do
    x = max(div(cols - @pulsar_width, 2), 1)
    y = max(div(rows - @pulsar_height, 2), 8)

    Alaja.CLI.Commands.Show.Pulsar.run([
      "Alaja",
      "--raw",
      "--pos-x",
      Integer.to_string(x),
      "--pos-y",
      Integer.to_string(y),
      "--width",
      Integer.to_string(@pulsar_width),
      "--height",
      Integer.to_string(@pulsar_height),
      "--duration",
      Integer.to_string(@pulsar_ms),
      "--speed",
      Integer.to_string(@pulsar_speed)
    ])
  end

  defp terminal_size do
    cols =
      case :io.columns() do
        {:ok, c} -> c
        _ -> 80
      end

    rows =
      case :io.rows() do
        {:ok, r} -> r
        _ -> 24
      end

    {max(cols, 60), max(rows, 16)}
  end
end
