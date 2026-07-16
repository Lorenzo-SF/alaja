defmodule Alaja.Components.Progress do
  @moduledoc """
  Simple progress bar that runs in the current process.

  Use this for non-GenServer workflows (e.g. `delfos scan` and
  `delfos init` need a bar for a single parallel task that uses
  `Task.async_stream`). For multi-task UIs use `Alaja.Components.MultiBar`.

  ## Example

      bar = Alaja.Components.Progress.new(label: "Scanning", total: 207)
      Enum.each(items, fn item ->
        do_work(item)
        Alaja.Components.Progress.tick(bar)
      end)
      Alaja.Components.Progress.finish(bar)

  Renders to stderr so it doesn't pollute stdout. Falls back to a
  no-op (just logs) if stderr is not a TTY.

  ## Options

    * `:label` — bar prefix (default: `"Working"`)
    * `:width` — bar width in chars (default: 40)
    * `:animation` — `:spinner | :kitt | :pulse | :wave | :rainbow`
      (default: `:spinner`)
    * `:no_color` — disable ANSI output (default: `false`)
  """

  alias Alaja.Buffer
  alias Alaja.Components.AnimatedBar

  defstruct [:label, :total, :width, :animation, :position, :started_at, :nocolor, :enabled]

  @doc "Creates a new progress bar state. Pass to `tick/1` and `finish/1`."
  @spec new(keyword()) :: %__MODULE__{}
  def new(opts \\ []) do
    tty = tty?()
    nocolor = not tty or Keyword.get(opts, :no_color, false)

    %__MODULE__{
      label: Keyword.get(opts, :label, "Working"),
      total: Keyword.get(opts, :total, 0),
      width: Keyword.get(opts, :width, 40),
      animation: Keyword.get(opts, :animation, :spinner),
      position: 0,
      started_at: System.monotonic_time(:millisecond),
      nocolor: nocolor,
      enabled: tty and not nocolor
    }
  end

  @doc "Renders the current state. Call after each unit of work."
  @spec tick(%__MODULE__{}) :: %__MODULE__{}
  def tick(bar) do
    bar = %{bar | position: bar.position + 1}
    render(bar)
    bar
  end

  @doc """
  Renders the bar at a specific value (does not increment position).
  Useful for setting the initial state or jumping to a known value.
  """
  @spec render_at(%__MODULE__{}, non_neg_integer()) :: %__MODULE__{}
  def render_at(bar, current) do
    bar = %{bar | position: current}
    render(bar)
    bar
  end

  @doc "Marks the bar as complete and prints a final newline."
  @spec finish(%__MODULE__{}) :: :ok
  def finish(bar) do
    render(bar, finished: true)
    IO.write(:stderr, "\n")
    :ok
  end

  defp render(bar, opts \\ []) do
    if bar.enabled do
      buf =
        AnimatedBar.render_frame(bar.position, bar.total, bar.position,
          label: "#{bar.label}: ",
          width: bar.width,
          animation: bar.animation
        )

      # Cursor to column 0, clear line, write buffer, show cursor.
      # We always repaint in-place (no flicker) by resetting to col 0
      # and clearing from there.
      finished = Keyword.get(opts, :finished, false)
      suffix = if finished, do: " ✓", else: ""

      elapsed = System.monotonic_time(:millisecond) - bar.started_at

      eta =
        if bar.position > 0 and not finished do
          avg = elapsed / bar.position
          remaining = bar.total - bar.position
          secs_left = max(0, round(remaining * avg / 1000))
          " (ETA: #{secs_left}s, elapsed: #{div(elapsed, 1000)}s)"
        else
          " (elapsed: #{div(elapsed, 1000)}s)"
        end

      IO.write(:stderr, "\r\e[K")
      IO.write(:stderr, Buffer.to_iodata(buf))
      IO.write(:stderr, suffix)
      IO.write(:stderr, eta)
    end
  end

  defp tty? do
    case :io.getopts(:standard_error) do
      {:ok, opts} -> Keyword.get(opts, :tty, false)
      _ -> false
    end
  end
end
