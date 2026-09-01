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
  below the pulsar) asks whether to show the full help. `yes` clears the
  screen and returns `:help` (the caller renders the full help); `no`
  clears the screen and returns `:done`, leaving the terminal free.

  Skipped when stdout is not a TTY and when `ALAJ: NO_SHOWCASE` is set
  to `1`, `true` or `yes`.
  """

  alias Alaja.ANSI
  alias Alaja.Printer

  @default_theme "catppuccin"
  @help_question "¿Quieres ver el help?"
  @pulsar_duration_ms 70_000
  @pulsar_speed 60

  @description "Terminal UI & Process Orchestration Framework"

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
    ensure_first_run!()
    {cols, rows} = terminal_size()
    {x, y, width, height} = pulsar_geometry(cols, rows)

    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.hide_cursor()])

    pulsar_task = start_pulsar(x, y, width, height)

    answer = ask_help(cols, y + height + 1)

    Task.shutdown(pulsar_task, :brutal_kill)

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

  defp ask_help(cols, row) do
    pad = max(div(cols - String.length(@help_question), 2), 0)

    block =
      [@help_question, "", "  1. Y", "  2. N"]
      |> Enum.map_join("\n", &(String.duplicate(" ", pad) <> &1))

    Printer.print(block, raw: true, pos_x: 0, pos_y: row, color: {0, 180, 216})

    IO.write([ANSI.move_to(pad, row + 4), ANSI.show_cursor()])

    parse_answer(IO.gets("> "))
  end

  defp parse_answer(:eof), do: :no

  defp parse_answer(answer) do
    case answer |> String.trim() |> String.downcase() do
      "" -> :no
      "y" -> :yes
      "yes" -> :yes
      "1" -> :yes
      _ -> :no
    end
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
