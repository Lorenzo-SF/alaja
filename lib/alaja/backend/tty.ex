defmodule Alaja.Backend.Tty do
  @moduledoc """
  Real-terminal backend. Writes the frame to stdout using raw ANSI
  escape sequences. Wraps each frame write in a CSI ?2026 sync block
  for tear-free updates on terminals that support it.

  The current implementation is intentionally minimal — the full
  renderer (style changes, cursor moves, skip-N) is implemented in
  AL-3. This module ships with a `render/2` that writes the frame
  row-by-row and is sufficient for AL-2's tests.
  """

  @behaviour Alaja.Backend

  alias Alaja.Frame

  @type state :: %{
          size: {pos_integer(), pos_integer()},
          raw_mode: boolean()
        }

  @doc false
  def init(opts) do
    size = Keyword.get(opts, :size, default_size())
    raw = Keyword.get(opts, :raw_mode, true)
    {:ok, %{size: size, raw_mode: raw}}
  end

  @doc false
  def render(state, %Frame{} = frame) do
    rows = render_rows(frame)
    IO.write(:stdio, "\e[?2026h")
    IO.write(:stdio, ["\e[H", rows])
    IO.write(:stdio, "\e[?2026l")
    {:ok, state}
  end

  @doc false
  def size(state), do: state.size

  @doc false
  def read_event(_state), do: {:error, :no_input}

  @doc false
  def shutdown(state) do
    IO.write(:stdio, "\e[0m\e[?25h\e[?1049l")
    {:ok, state}
  end

  defp render_rows(%Frame{} = f) do
    1..f.buffer.height
    |> Enum.map(fn row ->
      Frame.row_text(f, row)
    end)
    |> Enum.join("\r\n")
  end

  defp default_size do
    case :io.columns() do
      {:error, _} -> 80
      cols when is_integer(cols) and cols > 0 ->
        case :io.rows() do
          {:error, _} -> {cols, 24}
          rows when is_integer(rows) and rows > 0 -> {cols, rows}
          _ -> {cols, 24}
        end
      _ -> {80, 24}
    end
  end
end
