defmodule Alaja.Components.MultiBar do
  @moduledoc """
  Multi-task progress bar component for tracking parallel operations.

  Built on top of `Alaja.Components.Table`, rendering each task as a row
  with columns: **label** | **progress bar** | **status icon** | **description**.

  Uses ANSI cursor positioning for in-place updates without flickering.

  ## Task status flow

      running ──→ success
        │   ╰──→ error
        ╰─────→ wait ──→ running
                  ╰─→ error

  ## Usage

      {:ok, pid} = MultiBar.start_link(
        tasks: [
          %{id: :scan, label: "File Scanner"},
          %{id: :embed, label: "Embeddings"},
          %{id: :graph, label: "Graph Builder"}
        ],
        title: "Indexing Project",
        table_border: :rounded
      )

      MultiBar.progress(pid, :scan, 45, "lib/auth.ex")
      MultiBar.success(pid, :scan, "127 files indexed")
      MultiBar.error(pid, :embed, "server unreachable")
      MultiBar.wait(pid, :graph, "DB connection pending")
      MultiBar.info(pid, :scan, "Skipping _build/")

      MultiBar.done(pid)

  ## Options (global)

    * `:title` — title displayed above the bars
    * `:table_border` — border style (`:normal`, `:rounded`, `:double`, `:none`)
    * `:table_align` — table alignment (`:left`, `:center`, `:right`)
    * `:box` — wrap in box (default: `false`); see `Alaja.Printer`
    * `:box_title` — box title
    * `:box_border` — box border style
    * `:box_color` — box border color
    * `:padding` — cell padding (default: 1)
    * `:bar_width` — progress bar width in chars (default: 40)
    * `:bar_filled_char` — char for filled portion (default: "▓")
    * `:bar_empty_char` — char for empty portion (default: "░")
    * `:headers_color` — color for header row
    * `:headers_effects` — effects for header row
    * `:status_color` — status-specific color overrides:
        `%{running: :cyan, success: :green, error: :red, wait: :yellow, info: :blue}`

  ## Per-task options

    * `:label` — task display name (required)
    * `:description` — initial description text
    * `:bar_color` — specific color for this task's bar
  """

  use GenServer

  alias Alaja.Components.Table
  alias Alaja.Structures.ChunkText

  @typedoc "Internal state of one task"
  @type task_state :: %{
          id: atom(),
          label: String.t(),
          progress: non_neg_integer(),
          status: :running | :success | :error | :wait | :info,
          status_text: String.t(),
          description: String.t(),
          bar_color: {integer(), integer(), integer()} | nil
        }

  @typedoc "MultiBar internal state"
  @type t :: %{
          tasks: %{atom() => task_state()},
          titles: [String.t()],
          opts: keyword(),
          sorted_ids: [atom()],
          first_line: integer() | nil,
          line_count: non_neg_integer(),
          done: boolean()
        }

  # ── Colour palette by status ────────────────────────────────────────────────

  @status_colors %{
    running: {0, 180, 216},
    success: {0, 200, 80},
    error: {220, 50, 50},
    wait: {220, 180, 0},
    info: {100, 160, 220}
  }

  @status_icons %{
    running: "⟳",
    success: "✓",
    error: "✗",
    wait: "⏸",
    info: "ℹ"
  }

  @bar_filled_char "▓"
  @bar_empty_char "░"
  @bar_width 35

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc """
  Starts the MultiBar GenServer.

  ## Options (see `@moduledoc` for full list)

    * `:tasks` — list of `%{id: atom, label: String.t, ...}` (required)
    * `:name` — register under this name via `{:via, Registry, {registry, name}}`
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    tasks = Keyword.fetch!(opts, :tasks)
    gen_opts = if name = opts[:name], do: [name: name], else: []
    GenServer.start_link(__MODULE__, {tasks, opts}, gen_opts)
  end

  @doc "Reports progress (0-100) for a task with optional description."
  @spec progress(GenServer.server(), atom(), non_neg_integer(), String.t() | nil) :: :ok
  def progress(pid, task_id, pct, description \\ nil) do
    GenServer.cast(pid, {:progress, task_id, clamp_pct(pct), description})
  end

  @doc "Marks a task as successfully completed."
  @spec success(GenServer.server(), atom(), String.t() | nil) :: :ok
  def success(pid, task_id, message \\ nil) do
    GenServer.cast(pid, {:status, task_id, :success, message})
  end

  @doc "Marks a task as failed with an error message."
  @spec error(GenServer.server(), atom(), String.t() | nil) :: :ok
  def error(pid, task_id, message \\ nil) do
    GenServer.cast(pid, {:status, task_id, :error, message})
  end

  @doc "Marks a task as waiting/paused."
  @spec wait(GenServer.server(), atom(), String.t() | nil) :: :ok
  def wait(pid, task_id, reason \\ nil) do
    GenServer.cast(pid, {:status, task_id, :wait, reason})
  end

  @doc "Attaches an informational message to a task without changing its status."
  @spec info(GenServer.server(), atom(), String.t()) :: :ok
  def info(pid, task_id, message) do
    GenServer.cast(pid, {:info, task_id, message})
  end

  @doc """
  Stops the MultiBar, printing the final state.

  If `status` is `:all_success` and all tasks succeeded, prints a
  success summary.  Otherwise prints each task's final status.
  """
  @spec done(GenServer.server()) :: :ok
  def done(pid) do
    GenServer.call(pid, :done)
  end

  # ── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init({tasks, opts}) do
    title = Keyword.get(opts, :title)
    titles = if title, do: [title], else: []

    task_map =
      tasks
      |> Enum.with_index()
      |> Map.new(fn {t, _idx} ->
        id = Map.fetch!(t, :id)

        {id,
         %{
           id: id,
           label: Map.get(t, :label, to_string(id)),
           progress: 0,
           status: :running,
           status_text: "",
           description: Map.get(t, :description, "Initialising..."),
           bar_color: Map.get(t, :bar_color)
         }}
      end)

    sorted_ids = Enum.map(tasks, & &1.id)
    full_opts = Keyword.merge(default_opts(), opts)

    # Compute the number of visible lines (title + header + one row per task + borders).
    border = Keyword.get(full_opts, :table_border, :normal)
    header_lines = 1
    border_lines = if border == :none, do: 0, else: 3
    line_count = length(titles) + header_lines + length(sorted_ids) + border_lines

    state = %{
      tasks: task_map,
      titles: titles,
      opts: full_opts,
      sorted_ids: sorted_ids,
      first_line: nil,
      line_count: line_count,
      done: false
    }

    # Hide cursor, render initial frame
    IO.write(Alaja.ANSI.hide_cursor())

    rendered = render_table(state)
    # Measure actual rendered lines for future cursor repositioning
    actual_lines = count_lines(rendered)

    state = %{state | first_line: 0, line_count: actual_lines}
    IO.write(rendered)

    {:ok, state}
  end

  @impl true
  def handle_cast({:progress, task_id, pct, desc}, state) do
    state =
      update_task(state, task_id, fn t ->
        %{t | progress: pct, description: desc || t.description}
      end)

    refresh(state)
    {:noreply, state}
  end

  def handle_cast({:status, task_id, new_status, message}, state) do
    state =
      update_task(state, task_id, fn t ->
        %{
          t
          | status: new_status,
            status_text: message || task_label_for(new_status),
            progress: progress_for(new_status, t.progress)
        }
      end)

    refresh(state)
    {:noreply, state}
  end

  def handle_cast({:info, task_id, message}, state) do
    state =
      update_task(state, task_id, fn t ->
        %{t | description: message}
      end)

    refresh(state)
    {:noreply, state}
  end

  @impl true
  def handle_call(:done, _from, state) do
    # Move down past the bar area so final output doesn't overwrite
    lines_to_clear = state.line_count
    state = %{state | done: true}

    # Clear the bar area
    if state.first_line != nil do
      clear_lines(state.first_line, lines_to_clear)
    end

    # Print final state below
    final = render_table(state)
    IO.write(final)
    IO.write(Alaja.ANSI.show_cursor())
    IO.puts("")

    {:stop, :normal, :ok, state}
  end

  # ── Rendering ───────────────────────────────────────────────────────────────

  defp render_table(state) do
    rows = build_rows(state)
    border = Keyword.get(state.opts, :table_border, :normal)

    opts =
      state.opts
      |> Keyword.drop([
        :title,
        :tasks,
        :bar_width,
        :bar_filled_char,
        :bar_empty_char,
        :name,
        :status_color,
        :box,
        :box_title,
        :box_border,
        :box_color
      ])
      |> Keyword.put(:rows, rows)
      |> Keyword.put(:table_border, border)

    table = Table.render(opts)

    # Prepend title(s) above the table
    title_lines = Enum.map(state.titles, fn t -> format_title(t, state.opts) end)

    IO.iodata_to_binary([
      Enum.intersperse(title_lines, "\n"),
      (title_lines != [] && "\n") || "",
      Alaja.Buffer.to_iodata(table)
    ])
  end

  defp build_rows(state) do
    Enum.map(state.sorted_ids, fn id ->
      t = Map.fetch!(state.tasks, id)
      color = status_color(t, state.opts)

      label = render_cell(t.label, color, [])

      bar =
        if t.status in [:success, :done] do
          render_bar(t.progress, color, state.opts)
        else
          render_bar(t.progress, color, state.opts)
        end

      icon = status_icon(t)
      desc = truncate_text(t.description, 40)

      [label, bar, icon, desc]
    end)
  end

  defp render_bar(pct, color, opts) do
    width = Keyword.get(opts, :bar_width, @bar_width)
    filled_char = Keyword.get(opts, :bar_filled_char, @bar_filled_char)
    empty_char = Keyword.get(opts, :bar_empty_char, @bar_empty_char)

    clamped = clamp_pct(pct)
    filled = round(clamped * width / 100)
    empty = width - filled

    {r, g, b} = color || @status_colors.running

    filled_part =
      "#{Alaja.ANSI.fg(r, g, b)}#{String.duplicate(filled_char, filled)}#{Alaja.ANSI.reset()}"

    empty_part =
      "#{Alaja.ANSI.dim()}#{String.duplicate(empty_char, empty)}#{Alaja.ANSI.reset()}"

    pct_str = " #{String.pad_leading("#{clamped}%", 4)}"

    filled_part <> empty_part <> pct_str
  end

  defp render_cell(text, color, effects) do
    {r, g, b} = color || @status_colors.running
    ChunkText.render(ChunkText.new(text, color: {r, g, b}, effects: effects))
  end

  # ── ANSI cursor helpers ─────────────────────────────────────────────────────

  defp refresh(state) do
    if state.first_line != nil do
      # Move cursor to the start of the bar area, clear the whole block
      clear_lines(state.first_line, state.line_count)
      IO.write(render_table(state))
    else
      IO.write(render_table(state))
    end
  end

  defp clear_lines(start_line, count) do
    # Move cursor to start_line, clear N lines
    cursor_up = if start_line > 0, do: "\e[#{start_line}A", else: ""
    IO.write("#{cursor_up}")

    for _ <- 1..count do
      # clear current line
      IO.write("\e[K")
      if count > 1, do: IO.write("\n")
    end

    # Move back up to the start position
    if count > 0 do
      IO.write("\e[#{count}A")
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp update_task(state, task_id, fun) do
    Map.update!(state, :tasks, fn tasks ->
      Map.update!(tasks, task_id, fun)
    end)
  end

  defp status_color(t, opts) do
    overrides = Keyword.get(opts, :status_color, %{})
    Map.get(overrides, t.status) || Map.get(@status_colors, t.status, @status_colors.running)
  end

  defp status_icon(t) do
    color = status_color(t, [])
    {r, g, b} = color
    prefix = Alaja.ANSI.fg(r, g, b)
    suffix = Alaja.ANSI.reset()
    icon = Map.get(@status_icons, t.status, "")
    default_text = default_status_text(t.status)
    "#{prefix}#{icon} #{t.status_text || default_text}#{suffix}"
  end

  defp default_status_text(:running), do: ""
  defp default_status_text(:success), do: "Done"
  defp default_status_text(:error), do: "Failed"
  defp default_status_text(:wait), do: "Waiting"
  defp default_status_text(:info), do: ""

  defp format_title(title, opts) do
    align = Keyword.get(opts, :table_align, :left)
    width = Keyword.get(opts, :bar_width, @bar_width)
    # Simple bold title
    bold_title = "#{Alaja.ANSI.bold_on()}#{title}#{Alaja.ANSI.reset()}"

    case align do
      :center -> String.pad_leading(bold_title, div(width + String.length(title), 2))
      :right -> String.pad_leading(bold_title, width)
      _ -> bold_title
    end
  end

  defp clamp_pct(pct) when is_integer(pct), do: min(max(pct, 0), 100)
  defp clamp_pct(pct) when is_float(pct), do: min(max(round(pct), 0), 100)

  defp progress_for(:success, _old), do: 100
  defp progress_for(:error, old), do: old
  defp progress_for(:wait, old), do: old
  defp progress_for(:info, old), do: old

  defp task_label_for(:success), do: "Done"
  defp task_label_for(:error), do: "Failed"
  defp task_label_for(:wait), do: "Waiting"
  defp task_label_for(_), do: ""

  defp truncate_text(text, max_len) when byte_size(text) > max_len do
    String.slice(text, 0, max_len - 3) <> "..."
  end

  defp truncate_text(text, _max_len), do: text

  defp count_lines(iodata) do
    iodata
    |> IO.iodata_to_binary()
    |> String.split("\n", trim: true)
    |> length()
  end

  defp default_opts do
    [
      table_border: :rounded,
      table_align: :left,
      padding: 1,
      bar_width: @bar_width,
      bar_filled_char: @bar_filled_char,
      bar_empty_char: @bar_empty_char,
      headers: ["Task", "Progress", "Status", "Details"],
      headers_color: :bright,
      headers_effects: [:bold],
      rows_color: :white,
      status_color: %{}
    ]
  end
end
