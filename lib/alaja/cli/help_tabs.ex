defmodule Alaja.CLI.HelpTabs do
  @moduledoc """
  Tabbed help engine for the Alaja CLI.

  Renders help content as an interactive tab strip on a TTY, with the
  active panel's content displayed between the header and the
  navigation controls:

      ┌── header ─────────────────────────────┐
      │ Alaja CLI                              │
      │ Complete command reference             │
      │                                        │
      │ ─── DISPLAY COMMANDS ───               │  <- active panel
      │ ┌──────────┬────────────┐              │
      │ │ Command  │ Description│              │
      │ │ ...      │ ...        │              │
      │ └──────────┴────────────┘              │
      │                                        │
      │ [ Overview ]  Display  Stateful  ...   │  <- tab strip
      │ ←→ change tab    q/esc quit            │  <- hint
      └────────────────────────────────────────┘

  ## Rendering strategy

  * **Alternate screen** (`CSI ?1049h`) — all output goes to a private
    buffer. The terminal's scrollback is untouched; switching tabs does
    not produce historical frames.
  * **Scroll region** (`DECSTBM`) — limited to the panel area (header
    stays anchored, tab strip + hint stay anchored at the bottom).
  * **Sync output** (`CSI ?2026h`/`?2026l`) — wraps each repaint so the
    terminal batches updates into one frame (no flicker).

  ## Interaction

  * `←`/`→` or Tab — switch tabs
  * `q`/Esc — leave the help (alt screen closed)
  """

  alias Alaja.ANSI
  alias Alaja.Buffer
  alias Alaja.CLI.{GlobalOpts, Pagination, ViewText}
  alias Alaja.Components.Header
  alias Alaja.Printer

  @type panel :: %{label: String.t(), render: (-> String.t())}

  # Visual layout (constant for the help header — large size + subtitle).
  # Header occupies rows 1..4, blank on row 5. Scroll region starts on
  # row 6 and ends at the last viewport row.
  @header_height 5

  @header_opts [
    title: "Alaja CLI",
    subtitle: "Complete command reference",
    size: :large,
    color: {0, 180, 216},
    subtitle_color: {150, 150, 160}
  ]

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

  # ---------------------------------------------------------------------------
  # Interactive loop
  # ---------------------------------------------------------------------------

  defp interactive(panels, global) do
    IO.write(ANSI.alt_screen_on())
    IO.write(ANSI.hide_cursor())

    {_, bottom} = Alaja.Terminal.size()

    try do
      Pagination.raw_mode(fn ->
        # Lock the scroll region so the panel scrolls inside its own
        # window without dragging the header / tabs / hint.
        IO.write(ANSI.set_scroll_region(@header_height + 1, bottom))

        draw_full(panels, 0, global)
        loop(panels, 0, global)
      end)
    after
      IO.write(ANSI.show_cursor())
      IO.write(ANSI.alt_screen_off())
    end

    IO.write("\r\n")
    :ok
  end

  defp loop(panels, active, global) do
    case Pagination.read_key() do
      key when key in [:right, :tab] ->
        next = rem(active + 1, length(panels))
        draw_panel_only(panels, next, global)
        loop(panels, next, global)

      :left ->
        next = rem(active - 1 + length(panels), length(panels))
        draw_panel_only(panels, next, global)
        loop(panels, next, global)

      :esc ->
        :ok

      "q" ->
        :ok

      _ ->
        loop(panels, active, global)
    end
  end

  # ---------------------------------------------------------------------------
  # Drawing
  # ---------------------------------------------------------------------------

  # First paint: header + tab strip + hint + active panel.
  defp draw_full(panels, active, global) do
    IO.write(ANSI.sync_output_start())
    IO.write(ANSI.cursor_home())
    IO.write(ANSI.clear_screen())
    write_lines(header_text())
    draw_panel_only(panels, active, global)
    IO.write(ANSI.sync_output_end())
  end

  # Subsequent paints (tab change): redraw the panel area only. The
  # scroll region keeps the header anchored at the top and the tab
  # strip + hint anchored at the bottom of the viewport.
  defp draw_panel_only(panels, active, global) do
    IO.write(ANSI.sync_output_start())
    IO.write(ANSI.move_to(1, @header_height + 1))
    IO.write(ANSI.clear_line_down())

    text = render_panel(panels, active, global)
    write_lines(text)

    IO.write(ANSI.sync_output_end())
  end

  defp render_panel(panels, active, global) do
    body =
      panels
      |> Enum.at(active)
      |> Map.fetch!(:render)
      |> then(& &1.())
      |> Printer.format_raw(GlobalOpts.to_printer_opts(global))

    nav = nav_line(panels, active)

    try do
      body <> "\n\n" <> nav <> "\n" <> hint_line() <> "\n"
    rescue
      ArgumentError ->
        IO.warn(
          "[Alaja.HelpTabs.render_panel] body type: #{inspect(body[:__struct__] || :binary)}, nav type: #{inspect(nav[:__struct__] || :binary)}"
        )

        reraise __STACKTRACE__, __STACKTRACE__
    end
  end

  defp nav_line(panels, active) do
    labels = Enum.map(panels, & &1.label)
    state = %Alaja.Components.TabsState{labels: labels, active: active}
    Alaja.Components.tabs_view(state) |> ViewText.render()
  end

  defp hint_line do
    "\e[2m←→ change tab    q/esc quit\e[0m"
  end

  # The header is rendered once at the top of the alt screen and stays
  # pinned by the scroll region.
  defp header_text do
    buf =
      Header.render(
        @header_opts[:title],
        subtitle: @header_opts[:subtitle],
        size: @header_opts[:size],
        color: @header_opts[:color],
        subtitle_color: @header_opts[:subtitle_color]
      )

    buf |> Buffer.to_iodata() |> IO.iodata_to_binary()
  end

  # ---------------------------------------------------------------------------
  # Output helpers
  # ---------------------------------------------------------------------------

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