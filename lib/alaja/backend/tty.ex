defmodule Alaja.Backend.Tty do
  @moduledoc """
  Real-terminal backend. Writes the frame to stdout using raw ANSI
  escape sequences. Wraps each frame write in a CSI ?2026 sync block
  for tear-free updates on terminals that support it.

  Uses `Alaja.Renderer.diff/2` to emit only the cells that changed
  between the previous and the next frame.

  The state holds `prev_frame` so consecutive calls produce minimal
  diffs.
  """

  @behaviour Alaja.Backend

  alias Alaja.{Frame, Renderer}

  @type state :: %{
          size: {pos_integer(), pos_integer()},
          raw_mode: boolean(),
          prev_frame: Frame.t() | nil
        }

  @doc false
  def init(opts) do
    size = Keyword.get(opts, :size, default_size())
    raw = Keyword.get(opts, :raw_mode, true)
    {:ok, %{size: size, raw_mode: raw, prev_frame: nil}}
  end

  @doc false
  def render(state, %Frame{} = frame, _prev_frame) do
    diff = Renderer.diff(state.prev_frame, frame)
    IO.write(:stdio, "\e[?2026h")
    IO.write(:stdio, diff)
    IO.write(:stdio, "\e[?2026l")
    {:ok, %{state | prev_frame: frame}}
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
