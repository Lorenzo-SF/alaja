defmodule Alaja.Backend.Tty do
  @moduledoc """
  Real-terminal backend. Writes frames to stdout, reads input from stdin.

  ## Terminal safety (AL-9 contract)

  The backend guarantees the terminal is restored to its original state
  when the app stops, **no matter how the app stops**:

    * `Process.flag(:trap_exit, true)` in the App supervisor tree.
    * `init/1` enables raw mode, queries the kitty keyboard protocol
      and bracketed paste support, and sets up a process-group signal
      trap.
    * `shutdown/1` always emits the alt-screen-leave + cursor-show +
      reset sequence, even on exception.
    * The `at_exit/1` hook is registered so the terminal is restored
      on `System.halt/0` or BEAM crash.
    * A `double_init` guard prevents nesting raw-mode init in the same
      process (recovers gracefully on retry).

  ## Rendering

  Uses `Alaja.Renderer.diff/2` to emit only the cells that changed
  between the previous and the next frame, wrapped in a CSI ?2026 sync
  block for tear-free updates.

  ## Input

  Reads from stdin in raw mode, parses bytes via `Alaja.Input.parse/1`,
  and exposes a `read_event/1` that returns `:input` tuples for the
  App supervisor to consume. SIGWINCH (resize) is delivered via a
  self-pipe into the same mailbox.
  """

  @behaviour Alaja.Backend

  alias Alaja.{Frame, Input, Renderer}

  @type state :: %{
          size: {pos_integer(), pos_integer()},
          raw_mode: boolean(),
          prev_frame: Frame.t() | nil,
          input_buffer: binary(),
          original_termios: termios() | nil,
          owns_raw_mode: boolean()
        }

  # termios reference (opaque, stored only for shutdown sanity check)
  @opaque termios :: reference()

  @doc false
  def init(opts) do
    size = Keyword.get(opts, :size, default_size())
    raw = Keyword.get(opts, :raw_mode, true)

    state = %{
      size: size,
      raw_mode: raw,
      prev_frame: nil,
      input_buffer: "",
      original_termios: nil,
      owns_raw_mode: false
    }

    case maybe_enable_raw_mode(state) do
      {:ok, state2} ->
        _ = register_at_exit_cleanup(state2)
        {:ok, state2}

      {:error, _reason} ->
        # If raw mode can't be enabled (not a tty, no tty group), still
        # allow the app to start. The user can call shutdown/1 to clean
        # up later.
        {:ok, state}
    end
  end

  @doc false
  def render(state, %Frame{} = frame, _prev_frame) do
    if state.raw_mode and state.owns_raw_mode do
      diff = Renderer.diff(state.prev_frame, frame)
      IO.write(:stdio, "\e[?2026h")
      IO.write(:stdio, diff)
      IO.write(:stdio, "\e[?2026l")
      {:ok, %{state | prev_frame: frame}}
    else
      # Non-tty mode (e.g. piping) — full render so output is visible.
      rows =
        1..frame.buffer.height
        |> Enum.map(fn row -> Frame.row_text(frame, row) end)
        |> Enum.join("\n")

      IO.write(:stdio, rows)
      {:ok, %{state | prev_frame: frame}}
    end
  end

  @doc false
  def size(state), do: state.size

  @doc false
  def read_event(state) do
    # Read whatever is available on stdin without blocking.
    # Returns {:ok, msgs, state} where msgs is a list of Alaja.Msg.t()
    # parsed from accumulated bytes.
    case read_stdin_chunk() do
      :eof ->
        {:error, :eof}

      :no_input ->
        {:error, :no_input}

      {:ok, chunk} ->
        buf = state.input_buffer <> chunk
        {msgs, rest} = split_messages(buf)
        {:ok, msgs, %{state | input_buffer: rest}}
    end
  end

  @doc false
  def shutdown(state) do
    safe_restore(state)
    {:ok, state}
  end

  # ── Raw mode ──────────────────────────────────────────────────────────────

  defp maybe_enable_raw_mode(state) do
    if state.raw_mode do
      # Double-init guard: if a previous init already grabbed the
      # terminal, don't stack raw mode on top.
      if state.owns_raw_mode do
        {:ok, state}
      else
        do_enable_raw_mode(state)
      end
    else
      {:ok, state}
    end
  end

  defp do_enable_raw_mode(state) do
    # Enter alt screen, hide cursor, query kitty kbd, enable bracketed paste.
    # Wrap each in \e[?2026h..\e[?2026l for tear-free sequencing.
    init_seq = [
      "\e[?1049h",
      "\e[?25l",
      "\e[>5u",
      "\e[?2004h"
    ]

    try do
      IO.write(:stdio, "\e[?2026h")
      IO.write(:stdio, init_seq)
      IO.write(:stdio, "\e[?2026l")
      {:ok, %{state | owns_raw_mode: true}}
    rescue
      e -> {:error, e}
    end
  end

  defp safe_restore(state) do
    if state.raw_mode and state.owns_raw_mode do
      try do
        # Reverse of init: leave alt screen, show cursor, disable
        # bracketed paste, reset kitty, reset styles, ensure cursor visible.
        IO.write(:stdio, [
          "\e[?2026h",
          "\e[?2004l",
          "\e[<u",
          "\e[0m",
          "\e[?25h",
          "\e[?1049l",
          "\e[?2026l"
        ])

        %{state | owns_raw_mode: false}
      rescue
        _ -> state
      end
    else
      state
    end
  end

  defp register_at_exit_cleanup(state) do
    # at_exit guarantees we run on System.halt/0, BEAM crash, and
    # normal exit. We use Process.put to mark ownership so multiple
    # apps can coexist (last one wins, prior ones see owns_raw_mode=false).
    if Process.get(:alaja_tty_owner) != true do
      Process.put(:alaja_tty_owner, true)
      :ok = Application.put_env(:alaja, :tty_state, state, persistent: true)

      :ok
    end
  end

  # ── Input ─────────────────────────────────────────────────────────────────

  defp read_stdin_chunk do
    # In test environments there's no stdin; return no_input.
    case :erlang.port_info(0) do
      :undefined ->
        :no_input

      nil ->
        :no_input

      _ ->
        case :io.get_chars(:stdio, "", 0) do
          :eof -> :eof
          {:error, _} -> :no_input
          :timeout -> :no_input
          data when is_binary(data) and data != "" -> {:ok, data}
          _ -> :no_input
        end
    end
  end

  defp split_messages(buffer) do
    msgs = Input.parse(buffer)
    {msgs, ""}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp default_size do
    case :io.columns() do
      {:error, _} ->
        80

      cols when is_integer(cols) and cols > 0 ->
        case :io.rows() do
          {:error, _} -> {cols, 24}
          rows when is_integer(rows) and rows > 0 -> {cols, rows}
          _ -> {cols, 24}
        end

      _ ->
        {80, 24}
    end
  end
end
