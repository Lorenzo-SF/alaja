defmodule Alaja.CLI.Showcase do
  @moduledoc """
  Startup showcase for `alaja` invoked with no arguments (TTY only).

  On first run (no `~/.config/alaja/alaja.conf` and no installed themes)
  it silently does what `alaja theme init` would do and activates the
  default theme.

  It then draws a dynamic pulsar: 60% of the terminal width wide, 40% of
  the terminal height tall, 3 blank lines from the top, centered
  horizontally, pulsing with the theme's `gradient_1`..`gradient_6`
  colors and a multiline message with every line centered:

          alaja
      Terminal UI & Process Orchestration Framework
      tema activo: <name>

  The pulsar keeps pulsing while a centered yes/no prompt (a blank line
  below the pulsar) asks whether to show the full help. The prompt
  accepts arrow keys (←/→/↑/↓), vim-style `j`/`k`, numeric shortcuts
  (`1`/`2`), letter shortcuts (`y`/`n`), Enter to confirm, and `q`/Esc
  to fall back to the default (`no`).

  `yes` clears the screen and returns `:help` (the caller renders the
  full help); `no` clears the screen and returns `:done`, leaving the
  terminal free.

  Skipped when stdout is not a TTY and when `ALAJ: NO_SHOWCASE` is set
  to `1`, `true` or `yes`.
  """

  alias Alaja.ANSI
  alias Alaja.CLI.Pagination

  @help_question "¿Quieres ver el help?"
  # 8 s is a comfortable upper bound: the showcase waits for a key, but if
  # the user walks away the pulsar dies on its own before the prompt
  # becomes the only thing on screen.
  @pulsar_duration_ms 8_000
  @pulsar_speed 60

  @description "Terminal UI & Process Orchestration Framework"

  # ─── Options shown beneath the pulsar ──────────────────────────────────
  # `active` is the 0-based index of the highlighted option:
  #   0 → "1. Y"  (default index)
  #   1 → "2. N"
  @options [{"1. Y", :yes}, {"2. N", :no}]
  @default_active 1

  # ANSI dim-on / dim-off for the question line. We keep options at
  # default weight so the cursor `>` stays the visual anchor.
  @dim_open "\e[2m"
  @dim_close "\e[0m"
  # Cyan for the question (matches the original colour).
  @question_color {0, 180, 216}

  @doc """
  Whether the showcase should run: interactive TTY and not disabled
  through `ALAJ: NO_SHOWCASE`.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    IO.ANSI.enabled?() and
      System.get_env("ALAJ: NO_SHOWCASE") not in ["1", "true", "yes"]
  end

  @doc """
  Runs the showcase (blocking until the yes/no prompt is answered).

  Returns `:help` when the user wants to see the full help and `:done`
  otherwise.
  """
  @spec run() :: :help | :done
  def run do
    :ok = Alaja.Theme.Bootstrap.ensure_installed()
    {cols, rows} = terminal_size()
    {x, y, width, height} = pulsar_geometry(cols, rows)

    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.hide_cursor()])

    pulsar_task = start_pulsar(x, y, width, height)

    answer = ask_help(cols, y + height + 1)

    # The pulsar writes directly to stdout from a Task. `Task.shutdown`
    # kills the BEAM process, but bytes already queued in the kernel's
    # tty buffer will still arrive on the terminal after the kill.
    # A tiny sleep lets the kernel drain those frames; then our clear
    # wipes whatever the pulsar left behind. 30 ms is invisible to the
    # user and well below one frame of the pulsar (~60 ms).
    Task.shutdown(pulsar_task, :brutal_kill)
    Process.sleep(30)

    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.show_cursor()])

    case answer do
      :yes -> :help
      _ -> :done
    end
  end

  @doc """
  Builds the multiline pulsar content.

  Every line is centered over the widest line (the description), so all
  three lines are centered within the pulsar.
  """
  @spec pulsar_text() :: String.t()
  def pulsar_text do
    theme = to_string(Alaja.Config.get(:theme_active, :default))

    ["alaja", @description, "tema activo: #{theme}"]
    |> Enum.map_join("\n", &center_line(&1, String.length(@description)))
  end

  defp start_pulsar(x, y, width, height) do
    Task.async(fn ->
      Alaja.CLI.Commands.Show.Pulsar.run([
        pulsar_text(),
        "--raw",
        "--pos-x",
        Integer.to_string(x),
        "--pos-y",
        Integer.to_string(y),
        "--width",
        Integer.to_string(width),
        "--height",
        Integer.to_string(height),
        "--duration",
        Integer.to_string(@pulsar_duration_ms),
        "--speed",
        Integer.to_string(@pulsar_speed),
        "--colors",
        "theme:gradient_1|theme:gradient_2|theme:gradient_3|theme:gradient_4|theme:gradient_5|theme:gradient_6"
      ])
    end)
  end

  # ─── Interactive prompt (raw mode + arrow keys) ───────────────────────

  # The prompt is a 4-line block:
  #
  #     <question>           ← row 0 (relative to `row`)
  #                          ← row 1 (blank)
  #       1. Y               ← row 2 (option index 0)
  #    >  2. N               ← row 3 (option index 1, default active)
  #
  # We redraw only this block on every cursor move — the pulsar keeps
  # writing inside its own rectangle above and isn't touched.
  #
  # We use raw `IO.write` with explicit `\r\n` line terminators instead
  # of `Printer.print(raw: true, ...)`. `Printer.print` translates
  # `pos_y: row` to a 1-indexed cursor move (`row + 1`) and emits bare
  # `\n`, which doesn't return the carriage under raw mode (ONLCR off)
  # and produces ghost characters when re-rendering overlapping text.
  # Plain `IO.write` keeps the positioning and line endings predictable.
  defp ask_help(cols, row) do
    pad = max(div(cols - String.length(@help_question), 2), 0)
    draw_prompt(pad, row, @default_active)

    Pagination.raw_mode(fn -> loop_prompt(pad, row, @default_active) end)
  end

  # Keys that move the cursor: `:up`/`:down` (arrow keys), `k`/`j` (vim).
  # We treat them as a single class with a signed delta, so the case below
  # stays under credo's cyclomatic-complexity limit (≤ 9).
  @nav_keys [:up, :down, "k", "j"]

  defp loop_prompt(pad, row, active) do
    case Pagination.read_key() do
      key when key in @nav_keys ->
        delta = if key in [:up, "k"], do: -1, else: 1
        redraw_prompt(pad, row, active, wrap(active + delta))

      :enter ->
        commit(active)

      key when key in ["1", "y", "Y"] ->
        commit(0)

      key when key in ["2", "n", "N"] ->
        commit(1)

      key when key in [:esc, "q"] ->
        commit(@default_active)

      _ ->
        loop_prompt(pad, row, active)
    end
  end

  # `commit/1` doesn't need to keep drawing — once the user confirms we
  # let the caller redraw with `ANSI.clear()` after killing the pulsar.
  defp commit(active), do: elem(Enum.at(@options, active), 1)

  defp redraw_prompt(pad, row, _old, new_active) do
    draw_prompt(pad, row, new_active)
    loop_prompt(pad, row, new_active)
  end

  # Re-emit the 4-line block at absolute (col=1, row=row) with the given
  # option highlighted. The flow is:
  #
  #   1. Move cursor to (1, row) — top-left of the prompt block.
  #   2. `\e[J` erases everything from the cursor to the end of screen,
  #      so any ghost characters left by the previous render are gone.
  #   3. We write the block directly with explicit `\r\n` terminators.
  #      In raw mode the terminal doesn't translate `\n` → `\r\n`, so
  #      we MUST include the `\r` ourselves — otherwise lines wrap to
  #      column 0 and overwrite themselves.
  defp draw_prompt(pad, row, active) do
    IO.write(ANSI.move_to(1, row))
    IO.write(ANSI.clear_line_down())

    {r, g, b} = @question_color
    colour_open = "\e[38;2;#{r};#{g};#{b}m"

    block =
      [
        colour_open <> @dim_open <> @help_question <> @dim_close <> "\e[0m",
        "",
        render_option(pad, active, 0, "1. Y"),
        render_option(pad, active, 1, "2. N")
      ]
      |> Enum.join("\r\n")

    IO.write(block <> "\r\n")
  end

  defp render_option(pad, active, idx, label) do
    prefix = if idx == active, do: "> ", else: "  "
    String.duplicate(" ", pad) <> prefix <> label
  end

  defp wrap(i) do
    n = length(@options)
    if n == 0, do: 0, else: rem(rem(i, n) + n, n)
  end

  defp pulsar_geometry(cols, rows) do
    width = max(trunc(cols * 0.6), 20)
    height = max(trunc(rows * 0.4), 5)
    x = max(div(cols - width, 2), 0)
    y = 3

    {x, y, width, height}
  end

  defp center_line(line, width) do
    pad = max(div(width - String.length(line), 2), 0)
    String.duplicate(" ", pad) <> line
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
