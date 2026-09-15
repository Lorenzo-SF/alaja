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

    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.hide_cursor()])
    IO.write([ANSI.move_to(x, y - 1)])
    IO.puts(ANSI.fg(0, 180, 216) <> prompt <> ANSI.reset())
    draw_items(state, x, y, h)
    IO.write([ANSI.move_to(x, y + state.index - y), ANSI.show_cursor()])

    loop(state, x, y, h, cancel_keys)
  end

  defp loop(state, x, y, h, cancel_keys) do
    case read_key() do
      :eof ->
        cleanup()
        :cancelled

      {:char, c} when is_integer(c) ->
        ch = <<c::utf8>>

        if ch in cancel_keys do
          cleanup()
          :cancelled
        else
          loop(state, x, y, h, cancel_keys)
        end

      :enter ->
        item = Enum.at(state.items, state.index)
        cleanup()
        {:ok, item}

      :arrow_up ->
        next = max(state.index - 1, 0)
        redraw(%{state | index: next}, x, y, h)
        loop(%{state | index: next}, x, y, h, cancel_keys)

      :arrow_down ->
        next = min(state.index + 1, length(state.items) - 1)
        redraw(%{state | index: next}, x, y, h)
        loop(%{state | index: next}, x, y, h, cancel_keys)

      :arrow_left ->
        next = max(state.index - 1, 0)
        redraw(%{state | index: next}, x, y, h)
        loop(%{state | index: next}, x, y, h, cancel_keys)

      :arrow_right ->
        next = min(state.index + 1, length(state.items) - 1)
        redraw(%{state | index: next}, x, y, h)
        loop(%{state | index: next}, x, y, h, cancel_keys)

      :tab ->
        next = rem(state.index + 1, length(state.items))
        redraw(%{state | index: next}, x, y, h)
        loop(%{state | index: next}, x, y, h, cancel_keys)

      _ ->
        loop(state, x, y, h, cancel_keys)
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
      :eof -> :cancelled
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
      IO.write([ANSI.move_to(x, y + idx)])
      is_sel = idx == selected
      label = formatter.(item, is_sel)
      draw_row(label, is_sel)
    end)
  end

  defp redraw(state, x, y, h) do
    draw_items(state, x, y, h)
    IO.write([ANSI.show_cursor()])
  end

  defp draw_row(label, true) do
    IO.puts(ANSI.fg(0, 220, 180) <> "▶ " <> label <> ANSI.reset())
  end

  defp draw_row(label, false) do
    IO.puts(ANSI.fg(120, 120, 140) <> "  " <> label)
  end

  defp cleanup do
    IO.write([ANSI.clear(), ANSI.cursor_home(), ANSI.show_cursor()])
  end

  # ── raw key reading ─────────────────────────────────────────────

  defp read_key do
    case :io.getopts(:standard_io, [:binary, :echo]) do
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

  defp read_escape do
    case IO.read(:stdio, 1) do
      <<"[">> ->
        case IO.read(:stdio, 1) do
          <<"A">> -> :arrow_up
          <<"B">> -> :arrow_down
          <<"C">> -> :arrow_right
          <<"D">> -> :arrow_left
          <<"H">> -> :arrow_up
          <<"F">> -> :arrow_down
          _ -> :eof
        end
      _ -> :eof
    end
  end

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

  # ANSI helpers (avoid loading the full Alaja.ANSI here to keep picker fast).
  defmodule ANSI do
    def clear, do: "\e[2J"
    def cursor_home, do: "\e[H"
    def hide_cursor, do: "\e[?25l"
    def show_cursor, do: "\e[?25h"
    def move_to(x, y), do: "\e[#{y + 1};#{x + 1}H"

    def fg(r, g, b), do: "\e[38;2;#{r};#{g};#{b}m"
    def reset, do: "\e[0m"
  end
end
