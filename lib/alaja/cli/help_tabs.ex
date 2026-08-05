defmodule Alaja.CLI.HelpTabs do
  @moduledoc """
  Tabbed help engine for the Alaja CLI.

  Renders help content as an interactive tab strip (Description / Args /
  Examples) when stdin is a terminal, and as plain sequential sections
  when piped or redirected.

  ## Interaction

  * `←`/`→` or Tab — switch tabs
  * `q`/Esc — leave the help (the active panel stays on screen)

  ## Global options

  The active panel is drawn with `Alaja.Printer.format_raw/2` using the
  caller's global options, so `--box`, `--box-title`, `--box-border`,
  `--box-color` and `--align` apply to the panel content.
  """

  alias Alaja.CLI.{GlobalOpts, Pagination, ViewText}
  alias Alaja.Components
  alias Alaja.Printer

  @type panel :: %{label: String.t(), render: (-> String.t())}

  @doc """
  Renders the given panels, interactively on a TTY or sequentially
  otherwise.
  """
  @spec run([panel()], GlobalOpts.t()) :: :ok
  def run(panels, global) when is_list(panels) and panels != [] do
    if interactive?() do
      interactive(panels, global)
    else
      Enum.each(panels, &(&1.render.() |> write_lines()))
    end
  end

  @doc "Whether the interactive tabbed renderer should be used."
  @spec interactive?() :: boolean()
  def interactive? do
    Pagination.tty?()
  end

  defp interactive(panels, global) do
    IO.write(Alaja.ANSI.hide_cursor())

    try do
      Pagination.raw_mode(fn ->
        draw_dynamic(panels, 0, global)
        loop(panels, 0, global)
      end)
    after
      IO.write(Alaja.ANSI.show_cursor())
    end

    IO.write("\r\n")
    :ok
  end

  defp loop(panels, active, global) do
    case Pagination.read_key() do
      key when key in [:right, :tab] ->
        next = rem(active + 1, length(panels))
        draw_dynamic(panels, next, global)
        loop(panels, next, global)

      :left ->
        next = rem(active - 1 + length(panels), length(panels))
        draw_dynamic(panels, next, global)
        loop(panels, next, global)

      :esc ->
        :ok

      "q" ->
        :ok

      _ ->
        loop(panels, active, global)
    end
  end

  # Draws the dynamic area (tab strip + hint + active panel) anchored at
  # the saved cursor position, then restores the anchor and clears the
  # whole area so the next draw never leaves stale content behind.
  defp draw_dynamic(panels, active, global) do
    IO.write(Alaja.ANSI.save_cursor())
    write_lines("")

    draw_tab_strip(panels, active)
    draw_hint()

    panels
    |> Enum.at(active)
    |> Map.fetch!(:render)
    |> then(& &1.())
    |> print_panel(global)

    IO.write(Alaja.ANSI.restore_cursor())
    IO.write(Alaja.ANSI.clear_line_down())
  end

  defp draw_tab_strip(panels, active) do
    labels = Enum.map(panels, & &1.label)
    state = %Components.TabsState{labels: labels, active: active}

    ViewText.render(Components.tabs_view(state))
    |> write_lines()
  end

  defp draw_hint do
    write_lines(["\e[2m", "←→ change tab    q/esc quit", "\e[0m"])
  end

  defp print_panel(text, global) do
    text
    |> Printer.format_raw(GlobalOpts.to_printer_opts(global))
    |> write_lines()
  end

  # Raw-mode-safe writer: `\n` alone would not return the carriage on a
  # terminal in raw mode (ONLCR is off), so every newline is written as
  # `\r\n`. Plain `\r\n` output is harmless in normal (cooked) mode.
  defp write_lines(text) do
    text
    |> IO.iodata_to_binary()
    |> String.replace("\n", "\r\n")
    |> IO.write()
  end
end
