defmodule Alaja.CLI.Showcase do
  @moduledoc """
  Startup showcase for `alaja` invoked with no arguments (TTY only).

  On first run (no `~/.config/alaja/alaja.conf` and no installed themes)
  it silently does what `alaja theme init` would do and activates the
  default theme.

  Renders a dynamic pulsar while prompting the user to view full help.
  The prompt is a proper interactive picker:
    * `← →` (or `Tab`) move between options.
    * `Enter` selects.
    * `y`/`n` shortcut still works.
    * First option is selected by default (Enter immediately = yes).

  Skipped when stdout is not a TTY or `ALAJ_NO_SHOWCASE` is set.
  """

  alias Alaja.ANSI
  alias Alaja.Printer

  @default_theme "catppuccin"
  @help_question "¿Quieres ver el help?"
  @options [{:yes, "Yes — show full help"}, {:no, "No — exit"}]
  @pulsar_duration_ms 70_000
  @pulsar_speed 60

  @description "Terminal UI & Process Orchestration Framework"

  @doc """
  Whether the showcase should run: interactive TTY and not disabled
  through `ALAJ_NO_SHOWCASE`.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    IO.ANSI.enabled?() and
      System.get_env("ALAJ_NO_SHOWCASE") not in ["1", "true", "yes"]
  end

  @doc """
  Runs the showcase (blocking until the user selects an option).
  Returns `:help` or `:done`.
  """
  @spec run() :: :help | :done
  def run do
    ensure_first_run!()
    {cols, rows} = terminal_size()
    {x, y, width, height} = pulsar_geometry(cols, rows)

    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.hide_cursor()])

    pulsar_task = start_pulsar(x, y, width, height)

    answer = ask_interactive(cols, y + height + 1)

    Task.shutdown(pulsar_task, :brutal_kill)

    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.show_cursor()])

    answer
  end

  @doc """
  Builds the multiline pulsar content.

  Every line is centered over the widest line (the description).
  """
  @spec pulsar_text() :: String.t()
  def pulsar_text do
    theme = to_string(Alaja.Config.get(:theme_active, :default))

    ["alaja", @description, "tema activo: #{theme}"]
    |> Enum.map_join("\n", &center_line(&1, String.length(@description)))
  end

  # ── Interactive picker ──────────────────────────────────────────

  defp ask_interactive(cols, row) do
    opts = @options
    state = %{selected: 0}

    draw_picker(cols, row, opts, state)

    loop_picker(cols, row, opts, state)
  end

  defp loop_picker(cols, row, opts, state) do
    case read_key() do
      {:char, ?\r} ->
        elem(opts |> Enum.at(state.selected) |> elem(0))

      {:char, ?y} ->
        :help

      {:char, ?n} ->
        :done

      {:char, ?\t} ->
        next = rem(state.selected + 1, length(opts))
        redraw(cols, row, opts, %{state | selected: next})
        loop_picker(cols, row, opts, %{state | selected: next})

      {:arrow, :right} ->
        next = rem(state.selected + 1, length(opts))
        redraw(cols, row, opts, %{state | selected: next})
        loop_picker(cols, row, opts, %{state | selected: next})

      {:arrow, :left} ->
        prev = rem(state.selected - 1 + length(opts), length(opts))
        redraw(cols, row, opts, %{state | selected: prev})
        loop_picker(cols, row, opts, %{state | selected: prev})

      _ ->
        loop_picker(cols, row, opts, state)
    end
  end

  defp draw_picker(cols, row, opts, state) do
    pad = max(div(cols, 2) - 12, 0)

    IO.write([ANSI.move_to(pad, row)])
    Printer.print(@help_question, raw: true, pos_x: pad, pos_y: row, color: {0, 180, 216})

    IO.write([ANSI.move_to(0, row + 2)])
    render_options(opts, state.selected, pad, row + 2)
  end

  defp redraw(cols, row, opts, state) do
    pad = max(div(cols, 2) - 12, 0)
    IO.write([ANSI.move_to(0, row + 2), ANSI.clear_line()])
    render_options(opts, state.selected, pad, row + 2)
    IO.write([ANSI.show_cursor(), ANSI.move_to(0, row + 4)])
  end

  defp render_options(opts, selected, pad, y) do
    opts
    |> Enum.with_index()
    |> Enum.each(fn {{_atom, label}, idx} ->
      IO.write([ANSI.move_to(pad, y + idx)])
      icon = if idx == selected, do: "▶", else: " "
      color = if idx == selected, do: {0, 220, 180}, else: {120, 120, 140}

      label_padded = String.pad_trailing(label, 22)

      Printer.print("#{icon} #{label_padded}", raw: true, pos_x: pad, pos_y: y + idx, color: color)
    end)
  end

  # Reads a single key from stdin in raw mode.
  # Returns `{:char, codepoint}`, `{:arrow, :left | :right | :up | :down}`, or `:eof`.
  defp read_key do
    :io.getopts(:standard_io, [::binary, :echo])
    |> case do
      {:ok, opts} ->
        saved = opts
        new_opts = [{:echo, false}, {:binary, true}] |> Keyword.merge(opts)
        :io.setopts(:standard_io, new_opts)
        result = read_one_key()
        :io.setopts(:standard_io, saved)
        result

      _ ->
        # Fallback for non-tty: read line.
        case IO.gets("> ") do
          :eof -> :eof
          line -> {:char, hd(String.to_charlist(line))}
        end
    end
  rescue
    _ -> :eof
  end

  defp read_one_key do
    case IO.read(:stdio, 1) do
      :eof -> :eof
      <<27>> -> read_escape()
      <<c::utf8>> -> {:char, c}
    end
  end

  defp read_escape do
    case IO.read(:stdio, 1) do
      {:error, _} -> :eof
      <<"[">> ->
        case IO.read(:stdio, 1) do
          <<"A">> -> {:arrow, :up}
          <<"B">> -> {:arrow, :down}
          <<"C">> -> {:arrow, :right}
          <<"D">> -> {:arrow, :left}
          _ -> :eof
        end
      _ -> :eof
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────

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

  defp ensure_first_run! do
    conf = Path.expand("~/.config/alaja/alaja.conf")

    if not File.exists?(conf) or Alaja.Theme.list() == [] do
      File.mkdir_p!(Path.expand("~/.config/alaja/themes"))

      Enum.each(Alaja.Theme.templates(), &Alaja.Theme.install_template/1)
      Enum.each(Alaja.Theme.CustomTemplates.all(), &Alaja.Theme.install!/1)

      Alaja.Theme.activate(@default_theme)
      Alaja.Config.set(:theme_active, @default_theme)
    end
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
    cols = case :io.columns() do
      {:ok, c} -> c
      _ -> 80
    end

    rows = case :io.rows() do
      {:ok, r} -> r
      _ -> 24
    end

    {max(cols, 60), max(rows, 16)}
  end
end
