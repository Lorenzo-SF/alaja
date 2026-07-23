defmodule Alaja.CLI.Commands.Show.Multibar do
  @moduledoc """
  `alaja multibar` — Multi-task progress tracker with parallel bars.

  Displays multiple progress bars simultaneously, each tracking an
  independent task with states: running, success, error, wait, info.
  """

  alias Alaja.CLI.Commands.Show.Multibar.{Data, Renderer}
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.Parser
  alias Alaja.Components.{Header, MultiBar, Separator, Table}

  @default_duration 5
  @default_bar_width 35
  @tick_ms 200

  @doc "Runs the `alaja multibar` command — drives all bars concurrently until each finishes or its duration elapses."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _positional, _} =
      OptionParser.parse(rest,
        switches: [
          tasks: :string,
          title: :string,
          duration: :integer,
          stdin: :boolean,
          border: :string,
          bar_width: :integer,
          bar_color: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      run_multibar(opts, global)
    end
  end

  defp run_multibar(opts, global) do
    tasks_str = Keyword.get(opts, :tasks)

    if is_nil(tasks_str) or tasks_str == "" do
      help()
    else
      case Data.parse_tasks(tasks_str) do
        {:ok, tasks} ->
          run_multibar_with_tasks(opts, global, tasks)

        {:error, msg} ->
          IO.puts(:stderr, "Error: #{msg}")
          exit({:shutdown, 1})
      end
    end
  end

  defp run_multibar_with_tasks(opts, global, tasks) do
    title = Keyword.get(opts, :title)
    duration = Keyword.get(opts, :duration, @default_duration)
    border = Data.parse_border(Keyword.get(opts, :border, "rounded"))
    bar_width = Keyword.get(opts, :bar_width, @default_bar_width)
    bar_color = Parser.parse_color_opt(Keyword.get(opts, :bar_color))

    multibar_opts =
      [
        tasks: tasks,
        title: title,
        table_border: border,
        bar_width: bar_width,
        bar_color: bar_color
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    if global.stdin or Keyword.get(opts, :stdin, false) do
      run_stdin_mode(multibar_opts, global)
    else
      run_demo_mode(multibar_opts, global, duration)
    end
  end

  defp run_demo_mode(multibar_opts, _global, duration_sec) do
    duration_ms = duration_sec * 1000
    ticks = max(1, div(duration_ms, @tick_ms))
    tasks = Keyword.get(multibar_opts, :tasks, [])

    task_state_map = Map.new(tasks, fn t -> {t.id, :running} end)
    progress_map = Map.new(tasks, fn t -> {t.id, 0} end)

    case MultiBar.start_link(multibar_opts) do
      {:ok, pid} ->
        run_demo_animation(pid, ticks, multibar_opts, task_state_map, progress_map, tasks)

      {:error, reason} ->
        IO.puts(:stderr, "Error starting MultiBar: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp run_demo_animation(pid, ticks, opts, task_state_map, progress_map, tasks) do
    # credo:disable-for-next-line
    try do
      Renderer.demo_loop(pid, ticks, opts, task_state_map, progress_map)

      total = length(tasks)

      failed =
        Enum.count(tasks, fn t ->
          case Process.get({:task_state, t.id}, :running) do
            :failed -> true
            _ -> false
          end
        end)

      succeeded = total - failed

      Process.put(:demo_summary, {failed, succeeded, total})

      Process.sleep(@tick_ms * 2)
    after
      MultiBar.done(pid)

      Renderer.print_demo_summary()

      Process.delete(:demo_summary)

      Enum.each(tasks, fn t -> Process.delete({:task_state, t.id}) end)
    end
  end

  defp run_stdin_mode(multibar_opts, _global) do
    if Renderer.stdin_tty?() do
      IO.puts("Multibar stdin mode — reading commands from pipe...")
      IO.puts("Use: echo 'progress tdai 50' | alaja multibar --tasks 'tdai:TD-AI' --stdin")
      IO.puts("")
      help()
    end

    case MultiBar.start_link(multibar_opts) do
      {:ok, pid} ->
        try do
          Renderer.read_stdin_loop(pid)
        after
          MultiBar.done(pid)
        end

      {:error, reason} ->
        IO.puts(:stderr, "Error starting MultiBar: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  @spec help() :: :ok
  def help do
    Header.print("Alaja Multibar",
      subtitle: "Multi-task progress tracker with parallel bars",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Renders a live table with one progress bar per task. Each task has a")
    IO.puts("  status (⟳ running, ✓ success, ✗ error, ⏸ waiting, ℹ info) and an")
    IO.puts("  independent progress bar. The table repaints in-place.")
    IO.puts("")
    IO.puts("  Two modes:")
    IO.puts("    Demo mode (default)  — auto-animates for --duration seconds")
    IO.puts("    Stdin mode (--stdin) — you drive each task via pipe commands")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts(~s(  alaja multibar --tasks "id:Label;id2:Label2" [options]))
    IO.puts("")
    IO.puts("  --tasks format: semicolon-separated list, each item is id:Label.")
    IO.puts(~s[  The id is lowercase alphanumeric (e.g. "scan", "embed_01").])
    IO.puts("  The Label is what appears in the Task column of the table.")
    IO.puts("")
    IO.puts("  ── Demo mode (default) ──")

    IO.puts(
      ~s(    alaja multibar --tasks "scan:File Scanner;embed:Embeddings" --title "Indexing")
    )

    IO.puts("    Animates progress randomly for 5 seconds (or custom --duration).")
    IO.puts("")
    IO.puts("  ── Stdin mode ──")

    IO.puts(
      ~s(    echo -e 'progress scan 25\\nsuccess scan' | alaja multibar --tasks "scan:Scanner" --stdin)
    )

    IO.puts("    Pipe commands to control each task in real time.")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        [
          "--tasks STRING",
          "Yes",
          ~S(Semicolon-separated list of tasks. Each entry: id:Label. Id must match [a-z][a-z0-9]*.)
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--title TEXT", "string", "", "", "Title row displayed above the progress table"],
        ["--duration N", "integer", "1+", "5", "Demo mode: total animation time in seconds"],
        ["--stdin", "boolean", "", "false", "Enable stdin command mode instead of demo"],
        [
          "--border TYPE",
          "string",
          "normal, rounded, double, none",
          "rounded",
          "Table border style"
        ],
        [
          "--bar-width N",
          "integer",
          "1+",
          "35",
          "Width of each progress bar in characters"
        ],
        [
          "--bar-color COLOR",
          "string",
          "Any color format",
          "",
          "Color for the progress bars (applied to all tasks)"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("MODES (detailed)", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("")
    IO.puts("  Demo mode (default):")
    IO.puts("    Each task starts at 0% with status ⟳ running. Progress advances")
    IO.puts("    at random intervals for --duration seconds. Tasks may enter")
    IO.puts("    states: running → wait → running → success, or error at ≥ 60%.")
    IO.puts(~s[    At the end a summary is printed (e.g. "3/3 OK, 1 error").])
    IO.puts("")
    IO.puts("  Stdin mode (--stdin):")
    IO.puts("    Read commands from stdin (pipe or heredoc) until 'done' or EOF.")
    IO.puts("    Each command is one line. See COMMAND PROTOCOL below.")
    IO.puts("    If stdin is a TTY (interactive terminal), shows this help instead.")
    IO.puts("")

    Separator.print("COMMAND PROTOCOL (stdin mode)", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  One command per line. The id must match a task from --tasks.")
    IO.puts("")

    Table.print(
      headers: ["Command", "Format", "Description"],
      rows: [
        [
          "progress",
          ~S(progress <id> <pct> [desc]),
          "Update progress 0-100; desc shown in Details column"
        ],
        [
          "success",
          ~S(success <id> [msg]),
          "Mark task ✓ Done; optional message in Status column"
        ],
        ["error", ~S(error <id> [msg]), "Mark task ✗ Failed; optional message in Status column"],
        ["wait", ~S(wait <id> [reason]), "Pause task ⏸; reason shown in Status column"],
        ["info", ~S(info <id> <msg>), "Update Details column without changing status/progress"],
        ["done", "done", "Close multibar and print final table"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    IO.puts("  Examples of a complete stdin session:")
    IO.puts(~s(    progress scan 10 "scanning lib/"  ))
    IO.puts(~s(    progress scan 45 "lib/auth.ex"   ))
    IO.puts(~s(    info scan "Skipping _build/"     ))
    IO.puts(~s(    wait graph "DB connection down"   ))
    IO.puts(~s(    progress graph 30 "retrying..."   ))
    IO.puts(~s(    success embed "127 files indexed"))
    IO.puts(~s(    error graph "timeout"             ))
    IO.puts(~s(    done                              ))
    IO.puts("")

    Separator.print("GLOBAL OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--raw", "boolean", "", "false", "Print at raw coordinates"],
        ["--pos-x N", "integer", "0+", "0", "X coordinate (with --raw)"],
        ["--pos-y N", "integer", "0+", "0", "Y coordinate (with --raw)"],
        ["--verbose", "boolean", "", "false", "Verbose output"],
        ["--box", "boolean", "", "false", "Wrap output in a bordered box"],
        ["--box-title TEXT", "string", "", "", "Box title (requires --box)"],
        [
          "--box-border TYPE",
          "string",
          "rounded, single, double, bold, none",
          "rounded",
          "Border style (requires --box)"
        ],
        ["--box-color COLOR", "string", "Any color format", "", "Border color (requires --box)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("EXAMPLES", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Command", "Description"],
      rows: [
        [
          ~s(alaja multibar --tasks "scan:Scanner;embed:Embed;graph:Graph" --title "Indexing"),
          "Demo: 3 tasks, 5s animation"
        ],
        [
          ~s(alaja multibar --tasks "build:Build" --duration 10 --bar-color cyan),
          "Demo: single task, 10s, cyan bars"
        ],
        [
          ~s(echo 'progress scan 50' | alaja multibar --tasks "scan:Scanner" --stdin),
          "Stdin: single command, exits on EOF"
        ],
        [
          ~s(printf 'progress scan 25\\nsuccess scan' | alaja multibar --tasks "scan:Scanner" --stdin),
          "Stdin: progress then success via pipe"
        ],
        [
          ~S(alaja multibar --tasks "a:Alpha;b:Beta" --title "Test" --border double),
          "Custom border style (double)"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
  end
end
