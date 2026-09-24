defmodule Alaja.CLI.Picker do
  @moduledoc """
  Interactive single-select picker for the terminal.

  Renders a vertical list with the selected item highlighted; the user
  navigates with `←/→/↑/↓` or `Tab`, and confirms with `Enter`.

  ## Usage

      Alaja.CLI.Picker.run(["dracula", "nord", "catppuccin"],
        "Select a theme:",
        formatter: fn name -> name end
      )
      # => {:ok, "dracula"} | :cancelled

  ## Options

    * `:initial_index` — pre-selected index (default 0).
    * `:formatter` — `(item, is_selected) -> String.t()` per row.
    * `:cancel_keys` — list of single-char strings that cancel
      (default `["q", "Q"]`).

  iter-059: used by `alaja theme set` for the no-args interactive flow.

  Falls back to a non-interactive prompt when stdin is not a TTY.
  """

  @default_cancel_keys ["q", "Q", "\x03"]

  @doc """
  Runs the picker. Returns `{:ok, item}` or `:cancelled`.
  """
  @spec run([any()], String.t(), keyword()) :: {:ok, any()} | :cancelled
  def run(items, prompt, opts \\ []) when is_list(items) and is_binary(prompt) do
    cond do
      items == [] -> :cancelled
      not IO.ANSI.enabled?() -> non_interactive(items, prompt)
      true -> interactive(items, prompt, opts)
    end
  end

  # ── interactive ─────────────────────────────────────────────────

  defp interactive(items, prompt, opts) do
    initial = Keyword.get(opts, :initial_index, 0)
    formatter = Keyword.get(opts, :formatter, fn x -> to_string(x) end)
    cancel_keys = Keyword.get(opts, :cancel_keys, @default_cancel_keys)

    state = %{index: initial, items: items, formatter: formatter}

    {cols, rows} = {terminal_cols(), terminal_rows()}
    box_height = min(length(items), rows - 4)
    {x, y, h} = {max(div(cols, 2) - 20, 0), 2, max(box_height, 3)}

    IO.write([ansi().clear(), ansi().cursor_home(), ansi().hide_cursor()])
    IO.write([ansi().move_to(x, y - 1)])
    IO.puts(ansi().fg(0, 180, 216) <> prompt <> ansi().reset())
    draw_items(state, x, y, h)
    IO.write([ansi().move_to(x, y + state.index - y), ansi().show_cursor()])

    loop(state, x, y, h, cancel_keys)
  end

  defp loop(state, x, y, h, cancel_keys) do
    case read_key() do
      :eof ->
        cleanup()
        :cancelled

      {:char, c} when is_integer(c) ->
        handle_char(c, state, x, y, h, cancel_keys)

      :enter ->
        item = Enum.at(state.items, state.index)
        cleanup()
        {:ok, item}

      key when key in [:arrow_up, :arrow_down, :arrow_left, :arrow_right, :tab] ->
        next = next_index(state, key)
        redraw(%{state | index: next}, x, y, h)
        loop(%{state | index: next}, x, y, h, cancel_keys)

      _ ->
        loop(state, x, y, h, cancel_keys)
    end
  end

  defp handle_char(c, state, x, y, h, cancel_keys) do
    ch = <<c::utf8>>

    if ch in cancel_keys do
      cleanup()
      :cancelled
    else
      loop(state, x, y, h, cancel_keys)
    end
  end

  # Compute the next cursor index for a navigation key. `tab` wraps
  # around (last → first); arrows clamp at the ends.
  defp next_index(state, key) do
    last = length(state.items) - 1

    case key do
      :arrow_up -> max(state.index - 1, 0)
      :arrow_down -> min(state.index + 1, last)
      :arrow_left -> max(state.index - 1, 0)
      :arrow_right -> min(state.index + 1, last)
      :tab -> rem(state.index + 1, length(state.items))
    end
  end

  # ── non-interactive fallback ────────────────────────────────────

  defp non_interactive(items, prompt) do
    IO.puts(prompt)

    items
    |> Enum.with_index(1)
    |> Enum.each(fn {item, idx} ->
      IO.puts("  #{idx}. #{item}")
    end)

    case IO.gets("Choice (1-#{length(items)}): ") do
      :eof ->
        :cancelled

      input ->
        case Integer.parse(String.trim(input)) do
          {n, _} when n in 1..length(items)//1 -> {:ok, Enum.at(items, n - 1)}
          _ -> :cancelled
        end
    end
  end

  # ── drawing ─────────────────────────────────────────────────────

  defp draw_items(state, x, y, h) do
    items = state.items
    formatter = state.formatter
    selected = state.index

    items
    |> Enum.with_index()
    |> Enum.take(h)
    |> Enum.each(fn {item, idx} ->
      IO.write([ansi().move_to(x, y + idx)])
      is_sel = idx == selected
      label = formatter.(item, is_sel)
      draw_row(label, is_sel)
    end)
  end

  defp redraw(state, x, y, h) do
    draw_items(state, x, y, h)
    IO.write([ansi().show_cursor()])
  end

  defp draw_row(label, true) do
    IO.puts(ansi().fg(0, 220, 180) <> "▶ " <> label <> ansi().reset())
  end

  defp draw_row(label, false) do
    IO.puts(ansi().fg(120, 120, 140) <> "  " <> label)
  end

  defp cleanup do
    IO.write([ansi().clear(), ansi().cursor_home(), ansi().show_cursor()])
  end

  # ── raw key reading ─────────────────────────────────────────────

  defp read_key do
    case :io.getopts(:standard_io) do
      {:ok, opts} ->
        saved = opts
        new_opts = [{:echo, false}, {:binary, true}] |> Keyword.merge(opts)
        :io.setopts(:standard_io, new_opts)
        result = read_one()
        :io.setopts(:standard_io, saved)
        result

      _ ->
        {:char, hd(:binary.bin_to_list(IO.gets("> ") || "n"))}
    end
  rescue
    _ -> :eof
  end

  defp read_one do
    case IO.read(:stdio, 1) do
      :eof -> :eof
      <<27>> -> read_escape()
      <<"\r">> -> :enter
      <<"\n">> -> :enter
      <<"\t">> -> :tab
      <<127>> -> :backspace
      <<c::utf8>> -> {:char, c}
    end
  end

  # ANSI cursor-key sequences. `[[A`=up, `[[B`=down, `[[C`=right,
  # `[[D`=left, `[[H`=home (mapped to up), `[[F`=end (mapped to down).
  @ansi_csi_arrow_key %{
    ?A => :arrow_up,
    ?B => :arrow_down,
    ?C => :arrow_right,
    ?D => :arrow_left,
    ?H => :arrow_up,
    ?F => :arrow_down
  }

  defp read_escape do
    case IO.read(:stdio, 1) do
      <<"[", rest::binary>> -> translate_csi(rest)
      _ -> :eof
    end
  end

  defp translate_csi(<<c, _::binary>>) when is_map_key(@ansi_csi_arrow_key, c) do
    Map.fetch!(@ansi_csi_arrow_key, c)
  end

  defp translate_csi(_), do: :eof

  defp terminal_cols do
    case :io.columns() do
      {:ok, c} -> c
      _ -> 80
    end
  end

  defp terminal_rows do
    case :io.rows() do
      {:ok, r} -> r
      _ -> 24
    end
  end

  # Resolves the nested ANSI module once per call. The implementation
  # lives in a nested module to avoid loading the full Alaja.ANSI here
  # (picker is hot-path when `alaja` runs interactively).
  defp ansi, do: __MODULE__.ANSI

  # ANSI helpers (avoid loading the full Alaja.ANSI here to keep picker fast).
  defmodule ANSI do
    @moduledoc """
    Tiny ANSI escape emitter used by `Alaja.CLI.Picker`.

    Kept nested (and minimal) so the picker can be invoked quickly
    without pulling in the full `Alaja.ANSI` module. Only the codes
    the picker actually uses are emitted here.
    """

    @doc "Clears the entire screen."
    def clear, do: "\e[2J"

    @doc "Moves the cursor to the home position (top-left)."
    def cursor_home, do: "\e[H"

    @doc "Hides the terminal cursor."
    def hide_cursor, do: "\e[?25l"

    @doc "Shows the terminal cursor."
    def show_cursor, do: "\e[?25h"

    @doc "Moves the cursor to a 0-indexed (x, y) position."
    def move_to(x, y), do: "\e[#{y + 1};#{x + 1}H"

    @doc "Sets the foreground colour to the given 8-bit RGB triplet."
    def fg(r, g, b), do: "\e[38;2;#{r};#{g};#{b}m"

    @doc "Resets all SGR attributes."
    def reset, do: "\e[0m"
  end
end
