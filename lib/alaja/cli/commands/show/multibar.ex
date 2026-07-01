defmodule Alaja.CLI.Commands.Show.Multibar do
  @moduledoc """
  `alaja multibar` — Multi-task progress tracker with parallel bars.

  Displays multiple progress bars simultaneously, each tracking an
  independent task with states: running, success, error, wait, info.
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.Parser
  alias Alaja.Components.{Header, MultiBar, Separator, Table}

  @default_duration 5
  @default_bar_width 35
  @tick_ms 200

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

  # ── Main dispatch ────────────────────────────────────────────────────────────

  defp run_multibar(opts, global) do
    tasks_str = Keyword.get(opts, :tasks)

    if is_nil(tasks_str) or tasks_str == "" do
      help()
    else
      case parse_tasks(tasks_str) do
        {:ok, tasks} ->
          title = Keyword.get(opts, :title)
          duration = Keyword.get(opts, :duration, @default_duration)
          border = parse_border(Keyword.get(opts, :border, "rounded"))
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

        {:error, msg} ->
          IO.puts(:stderr, "Error: #{msg}")
          exit({:shutdown, 1})
      end
    end
  end

  # ── Demo mode ────────────────────────────────────────────────────────────────

  defp run_demo_mode(multibar_opts, _global, duration_sec) do
    duration_ms = duration_sec * 1000
    ticks = max(1, div(duration_ms, @tick_ms))
    tasks = Keyword.get(multibar_opts, :tasks, [])

    # Track per-task state: :running, :wait, :failed
    task_state_map = Map.new(tasks, fn t -> {t.id, :running} end)
    progress_map = Map.new(tasks, fn t -> {t.id, 0} end)

    case MultiBar.start_link(multibar_opts) do
      {:ok, pid} ->
        try do
          demo_loop(pid, ticks, multibar_opts, task_state_map, progress_map)

          # Final pass: mark all still-running tasks as success
          total = length(tasks)

          failed =
            Enum.count(tasks, fn t ->
              case Process.get({:task_state, t.id}, :running) do
                :failed -> true
                _ -> false
              end
            end)

          succeeded = total - failed

          # Store summary data for after block
          Process.put(:demo_summary, {failed, succeeded, total})

          # Small delay so user can see final state
          Process.sleep(@tick_ms * 2)
        after
          MultiBar.done(pid)

          # Print summary after multibar is done
          case Process.get(:demo_summary) do
            {failed, succeeded, total} when failed == 0 ->
              IO.puts("Demo completado: #{succeeded}/#{total} tareas finalizadas correctamente")

            {failed, succeeded, total} ->
              IO.puts("Demo completado: #{succeeded}/#{total} OK, #{failed} con error simulado")

            nil ->
              :ok
          end

          Process.delete(:demo_summary)

          # Cleanup Process dictionary
          Enum.each(tasks, fn t -> Process.delete({:task_state, t.id}) end)
        end

      {:error, reason} ->
        IO.puts(:stderr, "Error starting MultiBar: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp demo_loop(_pid, 0, _opts, _task_state_map, _progress_map), do: :ok

  defp demo_loop(pid, ticks_left, opts, task_state_map, progress_map) do
    tasks = Keyword.get(opts, :tasks, [])

    {new_task_state_map, new_progress_map} =
      Enum.reduce(tasks, {task_state_map, progress_map}, fn task, {state_acc, prog_acc} ->
        id = task.id
        current_state = Map.get(state_acc, id, :running)
        current_progress = Map.get(prog_acc, id, 0)

        cond do
          # Failed tasks: don't progress further
          current_state == :failed ->
            {state_acc, prog_acc}

          # Wait tasks: slowly advance but don't mark progress
          current_state == :wait ->
            # Resume to running with 30% chance per tick
            if :rand.uniform(3) == 1 do
              {Map.put(state_acc, id, :running), prog_acc}
            else
              {state_acc, prog_acc}
            end

          # Running tasks: progress + occasional fail/success
          true ->
            # 5% chance of failure, but only if progress >= 60 (advanced enough)
            cond do
              :rand.uniform(20) == 1 and current_progress >= 60 ->
                MultiBar.error(pid, id, "Fallo simulado")
                Process.put({:task_state, id}, :failed)
                {Map.put(state_acc, id, :failed), prog_acc}

              # 3% chance of wait
              :rand.uniform(33) == 1 and current_progress >= 20 and current_progress < 80 ->
                MultiBar.wait(pid, id, "Esperando recursos...")
                Process.put({:task_state, id}, :wait)
                {Map.put(state_acc, id, :wait), prog_acc}

              # Normal progress
              true ->
                increment = :rand.uniform(11) + 4
                new_progress = min(100, current_progress + increment)
                desc = description_for(id, ticks_left)
                MultiBar.progress(pid, id, new_progress, desc)
                {state_acc, Map.put(prog_acc, id, new_progress)}
            end
        end
      end)

    :timer.sleep(@tick_ms)
    demo_loop(pid, ticks_left - 1, opts, new_task_state_map, new_progress_map)
  end

  defp description_for(id, ticks_left) do
    idx = rem(ticks_left, 4)

    case idx do
      0 -> "Procesando #{id}..."
      1 -> "Validando #{id}..."
      2 -> "Cargando lote #{id}..."
      3 -> "Indexando bloque #{id}..."
    end
  end

  # ── Stdin mode ───────────────────────────────────────────────────────────────

  defp run_stdin_mode(multibar_opts, _global) do
    # If stdin is a TTY, print help and exit
    if stdin_tty?() do
      IO.puts("Multibar stdin mode — reading commands from pipe...")
      IO.puts("Use: echo 'progress tdai 50' | alaja multibar --tasks 'tdai:TD-AI' --stdin")
      IO.puts("")
      help()
    end

    case MultiBar.start_link(multibar_opts) do
      {:ok, pid} ->
        try do
          read_stdin_loop(pid)
        after
          MultiBar.done(pid)
        end

      {:error, reason} ->
        IO.puts(:stderr, "Error starting MultiBar: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp stdin_tty? do
    match?({:ok, true}, :io.columns())
  end

  defp read_stdin_loop(pid) do
    case IO.read(:stdio, :line) do
      :eof ->
        :ok

      line ->
        line = String.trim(line)

        cond do
          line == "" or String.starts_with?(line, "#") ->
            read_stdin_loop(pid)

          line == "done" ->
            :ok

          true ->
            case parse_stdin_command(line) do
              {:ok, cmd} ->
                execute_stdin_command(pid, cmd)

              {:error, msg} ->
                IO.puts(:stderr, "Error: #{msg}")
            end

            read_stdin_loop(pid)
        end
    end
  end

  # Command format: progress <task_id> <pct> [description]
  #                success <task_id> [message]
  #                error <task_id> [message]
  #                wait <task_id> [reason]
  #                info <task_id> <message>
  defp parse_stdin_command(line) do
    parts = String.split(line, " ", parts: 4) |> Enum.map(&String.trim/1)
    [cmd | args] = parts

    case cmd do
      "progress" ->
        case args do
          [task_id, pct_str] ->
            with {:ok, pct} <- parse_pct(pct_str) do
              {:ok, {:progress, String.to_atom(task_id), pct, nil}}
            end

          [task_id, pct_str, desc] ->
            with {:ok, pct} <- parse_pct(pct_str) do
              {:ok, {:progress, String.to_atom(task_id), pct, desc}}
            end

          _ ->
            {:error, "progress <task_id> <pct> [description]"}
        end

      "success" ->
        case args do
          [task_id] ->
            {:ok, {:status, String.to_atom(task_id), :success, nil}}

          [task_id, msg] ->
            {:ok, {:status, String.to_atom(task_id), :success, msg}}

          _ ->
            {:error, "success <task_id> [message]"}
        end

      "error" ->
        case args do
          [task_id] ->
            {:ok, {:status, String.to_atom(task_id), :error, nil}}

          [task_id, msg] ->
            {:ok, {:status, String.to_atom(task_id), :error, msg}}

          _ ->
            {:error, "error <task_id> [message]"}
        end

      "wait" ->
        case args do
          [task_id] ->
            {:ok, {:status, String.to_atom(task_id), :wait, nil}}

          [task_id, reason] ->
            {:ok, {:status, String.to_atom(task_id), :wait, reason}}

          _ ->
            {:error, "wait <task_id> [reason]"}
        end

      "info" ->
        case args do
          [task_id, msg] ->
            {:ok, {:info, String.to_atom(task_id), msg}}

          _ ->
            {:error, "info <task_id> <message>"}
        end

      _ ->
        {:error, "Unknown command '#{cmd}'"}
    end
  end

  defp parse_pct(str) do
    case Integer.parse(str) do
      {pct, _} when pct >= 0 and pct <= 100 -> {:ok, pct}
      {_pct, _} -> {:error, "percentage must be 0-100"}
      :error -> {:error, "invalid percentage value"}
    end
  end

  defp execute_stdin_command(pid, {:progress, task_id, pct, desc}) do
    MultiBar.progress(pid, task_id, pct, desc)
  end

  defp execute_stdin_command(pid, {:status, task_id, status, msg}) do
    case status do
      :success -> MultiBar.success(pid, task_id, msg)
      :error -> MultiBar.error(pid, task_id, msg)
      :wait -> MultiBar.wait(pid, task_id, msg)
    end
  end

  defp execute_stdin_command(pid, {:info, task_id, msg}) do
    MultiBar.info(pid, task_id, msg)
  end

  # ── Task parsing ─────────────────────────────────────────────────────────────

  defp parse_tasks(tasks_str) do
    tasks_str
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] ->
        {:error, "--tasks is required (format: id:label;id:label)"}

      parts ->
        Enum.reduce_while(parts, {:ok, []}, fn part, {:ok, acc} ->
          case parse_task_entry(part) do
            {:ok, task} -> {:cont, {:ok, [task | acc]}}
            {:error, msg} -> {:halt, {:error, msg}}
          end
        end)
        |> case do
          {:ok, tasks} -> {:ok, Enum.reverse(tasks)}
          error -> error
        end
    end
  end

  defp parse_task_entry(entry) do
    case String.split(entry, ":", parts: 2) do
      [id_str, label] ->
        id_str = String.trim(id_str)
        label = String.trim(label)

        cond do
          id_str == "" ->
            {:error, "task id cannot be empty in '#{entry}'"}

          label == "" ->
            {:error, "task label cannot be empty in '#{entry}'"}

          not valid_id?(id_str) ->
            {:error, "task id '#{id_str}' must be lowercase alphanumeric (got: '#{id_str}')"}

          true ->
            {:ok, %{id: String.to_atom(id_str), label: label}}
        end

      _ ->
        {:error, "task entry '#{entry}' must be in id:label format"}
    end
  end

  defp valid_id?(id_str) do
    String.match?(id_str, ~r/^[a-z][a-z0-9]*$/)
  end

  # ── Border parsing ───────────────────────────────────────────────────────────

  defp parse_border("normal"), do: :normal
  defp parse_border("rounded"), do: :rounded
  defp parse_border("double"), do: :double
  defp parse_border("none"), do: :none

  defp parse_border(other) do
    IO.puts(:stderr, "Warning: --border '#{other}' not valid, using 'rounded'")
    :rounded
  end

  # ── Help ─────────────────────────────────────────────────────────────────────

  @spec help() :: :ok
  def help do
    Header.print("Alaja Multibar",
      subtitle: "Multi-task progress tracker with parallel bars",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display multiple progress bars simultaneously, each tracking an")
    IO.puts("  independent task with states: running, success, error, wait, info.")
    IO.puts("  Supports two modes: demo (animated) and stdin (interactive).")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja multibar --tasks \"id:Label;id2:Label2\" [options]")
    IO.puts("")
    IO.puts("  # Demo mode (default) — animates for --duration seconds:")

    IO.puts(
      "  alaja multibar --tasks \"scan:File Scanner;embed:Embeddings\" --title \"Indexing\""
    )

    IO.puts("")
    IO.puts("  # Stdin mode — reads commands from pipe:")
    IO.puts("  echo 'progress scan 50' | alaja multibar --tasks \"scan:Scanner\" --stdin")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        [
          "--tasks STRING",
          "Yes",
          "Semicolon-separated list of tasks in id:label format. Ids must be lowercase alphanumeric."
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
        ["--title TEXT", "string", "", "", "Title displayed above the progress table"],
        ["--duration N", "integer", "1+", "5", "Demo mode duration in seconds"],
        ["--stdin", "boolean", "", "false", "Enable stdin interactive mode"],
        [
          "--border TYPE",
          "string",
          "normal, rounded, double, none",
          "rounded",
          "Table border style"
        ],
        ["--bar-width N", "integer", "1+", "35", "Width of each progress bar in characters"],
        ["--bar-color COLOR", "string", "Any color format", "", "Color for the progress bars"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("MODES", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Demo mode (default):")
    IO.puts("    Animates all tasks with random progress for --duration seconds.")
    IO.puts("    Tasks randomly succeed, fail, or pause to demonstrate all states.")
    IO.puts("")
    IO.puts("  Stdin mode (--stdin):")
    IO.puts("    Reads commands from stdin until 'done' or EOF.")
    IO.puts("    If stdin is a TTY (interactive terminal), shows this help instead.")
    IO.puts("")

    Separator.print("COMMAND PROTOCOL", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Available commands (case-sensitive):")
    IO.puts("")

    Table.print(
      headers: ["Command", "Format", "Description"],
      rows: [
        ["progress", "progress <id> <pct> [desc]", "Update task progress (0-100)"],
        ["success", "success <id> [msg]", "Mark task as successful"],
        ["error", "error <id> [msg]", "Mark task as failed"],
        ["wait", "wait <id> [reason]", "Mark task as waiting/paused"],
        ["info", "info <id> <msg>", "Show info message without changing state"],
        ["done", "done", "Close the multibar and show final state"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    IO.puts("  Examples:")
    IO.puts("    progress scan 45 \"lib/auth.ex\"")
    IO.puts("    success embed \"127 files indexed\"")
    IO.puts("    error embed \"server unreachable\"")
    IO.puts("    wait graph \"DB connection pending\"")
    IO.puts("    info scan \"Skipping _build/\"")
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
          "alaja multibar --tasks \"scan:Scanner;embed:Embeddings;graph:Graph\" --title \"Indexing\"",
          "Demo mode with 3 tasks"
        ],
        [
          "alaja multibar --tasks \"tdai:TD-AI;tdaudit:TD-Audit\" --duration 10",
          "Demo mode with custom duration"
        ],
        [
          "alaja multibar --tasks \"scan:Scanner\" --bar-width 50 --bar-color green",
          "Custom bar width and color"
        ],
        [
          "alaja multibar --tasks \"scan:Scanner;embed:Embeddings\" --title \"Processing\" --border double",
          "Double border style"
        ],
        [
          "echo -e 'progress scan 25\\nsuccess scan' | alaja multibar --tasks \"scan:Scanner\" --stdin",
          "Stdin mode with progress then success"
        ],
        [
          "echo 'done' | alaja multibar --tasks \"scan:Scanner\" --stdin",
          "Stdin mode — just close immediately"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")
    :ok
  end
end
