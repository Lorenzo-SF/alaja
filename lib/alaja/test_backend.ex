defmodule Alaja.TestBackend do
  @moduledoc """
  Virtual terminal backend for tests. Stores frames in a queue instead
  of writing to a real terminal.

  ## Usage

      backend_state = Alaja.TestBackend.init(width: 80, height: 24)
      {:ok, backend_state} = Alaja.TestBackend.render(backend_state, frame)
      assert Alaja.TestBackend.frame_text(backend_state, 1) =~ "hello"

  Or via `Alaja.App`:

      Alaja.App.start_link({MyApp, []}, backend: :test, backend_opts: [width: 80, height: 24])
  """

  @behaviour Alaja.Backend

  alias Alaja.Frame

  @type state :: %{
          width: pos_integer(),
          height: pos_integer(),
          frames: [Frame.t()],
          events: [{pid(), Msg.t()}],
          size: {pos_integer(), pos_integer()}
        }

  @doc false
  def init(opts) do
    w = Keyword.get(opts, :width, 80)
    h = Keyword.get(opts, :height, 24)
    {:ok, %{width: w, height: h, frames: [], events: [], size: {w, h}}}
  end

  @doc false
  def render(state, %Frame{} = frame) do
    {:ok, %{state | frames: [frame | state.frames]}}
  end

  @doc false
  def size(state), do: state.size

  @doc false
  def read_event(_state), do: {:error, :no_input}

  @doc false
  def shutdown(_state), do: :ok

  # ── Test helpers ──────────────────────────────────────────────────────────

  @doc "Returns the most recent frame, or nil if none rendered."
  @spec frame(state()) :: Frame.t() | nil
  def frame(state), do: state.frames |> List.first()

  @doc "Returns all rendered frames, newest first."
  @spec all_frames(state()) :: [Frame.t()]
  def all_frames(state), do: state.frames

  @doc "Returns the text content of a single row of the latest frame."
  @spec frame_text(state() | Frame.t(), pos_integer()) :: String.t()
  def frame_text(state, row) when is_integer(row) and row > 0 do
    case frame(state) do
      nil -> ""
      %Frame{} = f -> Frame.row_text(f, row)
    end
  end

  def frame_text(%Frame{} = f, row), do: Frame.row_text(f, row)

  @doc "Returns the full latest frame as a string (rows separated by newlines)."
  @spec frame_string(state()) :: String.t()
  def frame_string(state) do
    case frame(state) do
      nil -> ""

      %Frame{} = f ->
        1..f.buffer.height
        |> Enum.map(fn row -> Frame.row_text(f, row) end)
        |> Enum.join("\n")
    end
  end

  @doc "Injects a Msg into the test backend (for apps using `Alaja.App.update/2`)."
  @spec send_msg(state(), Msg.t() | map()) :: :ok
  def send_msg(state, msg) when is_map(msg) do
    {:ok, %{state | events: [{self(), msg} | state.events]}}
  end
end
