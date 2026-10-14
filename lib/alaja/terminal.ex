defmodule Alaja.Terminal do
  @moduledoc """
  Terminal size detection utilities.

  Wraps `:io.columns/0` and `:io.rows/0` with sensible fallbacks for
  non-TTY environments.
  """

  @doc """
  Returns the current terminal dimensions as `{columns, rows}`.

  Falls back to `{80, 24}` if the terminal size cannot be detected
  (e.g., in non-TTY environments, CI, or when stdout is redirected).
  """
  @spec size() :: {pos_integer(), pos_integer()}
  def size do
    {columns(), rows()}
  end

  @doc """
  Returns the terminal width in columns.
  """
  @spec width() :: pos_integer()
  def width, do: columns()

  @doc """
  Returns the terminal height in rows.
  """
  @spec height() :: pos_integer()
  def height, do: rows()

  @doc """
  Returns whether stdout is attached to an interactive terminal.

  This is Alaja's own TTY detection, and it exists because
  `IO.ANSI.enabled?/0` cannot answer the question in a release.

  `IO.ANSI.enabled?/0` is literally `Application.get_env(:elixir,
  :ansi_enabled, false)` (Elixir 1.18 and 1.19 alike) — it does **no** TTY
  detection of its own. That key is written by `Elixir.Kernel.CLI`, which
  only runs for the `elixir`/`mix` launcher. In a standalone release — a
  batamanta binary, an escript, `mix release` — it never runs, the key stays
  unset, and `IO.ANSI.enabled?/0` is hardcoded `false`. Every Alaja renderer
  gates colour on that answer, so such a release painted monochrome no
  matter what the terminal supported.

  Uses `/dev/fd/1` rather than sniffing `TERM`: `TERM` is an inherited
  string that happily survives a pipe (`TERM=xterm sh -c 'echo hi > f'`),
  so it says nothing about whether *this* process owns a terminal.

  The obvious POSIX probe, `sh -c '[ -t 1 ]'`, cannot answer it from the
  BEAM and silently answers the wrong thing. `System.cmd/3` — and every
  `:erlang.open_port/2` — replaces the child's fd 1 with a capture pipe,
  so `[ -t 1 ]` sees that pipe and is `false` even at a real terminal.
  Asking about fd 2 instead does work, because `System.cmd/3` leaves stderr
  inherited — but that tests stderr, not stdout, so `alaja … > out.txt`
  reports a terminal that is not there and writes ANSI into the file.

  `File.stat("/dev/fd/1")` is resolved by the kernel against the calling
  process's own descriptors, so this is the BEAM's real stdout, and no
  subprocess is involved. A terminal is the one case that reports
  `:device`; a pipe or socket reports `:other` and a redirected file
  `:regular`. `/dev/fd/1` exists on both Linux and macOS.

  Cached in `:persistent_term` because the question is asked once per
  rendered cell.
  """
  @spec tty?() :: boolean()
  def tty? do
    case :persistent_term.get(__MODULE__, nil) do
      nil ->
        detected = detect_tty?()
        :persistent_term.put(__MODULE__, detected)
        detected

      cached ->
        cached
    end
  end

  defp detect_tty?, do: device?("/dev/fd/1")

  @doc """
  Si `path` es un dispositivo de caracteres.

  Aislada de `tty?/0` para poder testear la sonda sin montar una terminal:
  el test necesita un carácter de dispositivo **real** contra el que
  compararse, y `/dev/tty` lo es — es un nodo `S_IFCHR` exista o no
  terminal de control, en Linux igual que en macOS.

  No es pública por diseño; se expone para el test, que es donde se
  comprueba que la sonda distingue algo.
  """
  @spec device?(Path.t()) :: boolean()
  def device?(path) do
    match?({:ok, %File.Stat{type: :device}}, File.stat(path))
  rescue
    # No `/dev` (Windows), o el stat fue rechazado. "No es terminal" es
    # la respuesta segura: es lo que Alaja reportaba en todas partes
    # antes de que existiera esta función.
    _ -> false
  end

  defp columns do
    case :io.columns() do
      {:ok, n} when n > 0 -> n
      _ -> 80
    end
  end

  defp rows do
    case :io.rows() do
      {:ok, n} when n > 0 -> n
      _ -> 24
    end
  end
end
