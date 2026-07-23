defmodule Alaja.CLI.Commands.Show.Multibar.Renderer do
  @moduledoc false

  alias Alaja.CLI.Commands.Show.Multibar.Data
  alias Alaja.Components.MultiBar

  @tick_ms 200

  @doc false
  def print_demo_summary do
    case Process.get(:demo_summary) do
      {failed, succeeded, total} when failed == 0 ->
        IO.puts("Demo completado: #{succeeded}/#{total} tareas finalizadas correctamente")

      {failed, succeeded, total} ->
        IO.puts("Demo completado: #{succeeded}/#{total} OK, #{failed} con error simulado")

      nil ->
        :ok
    end
  end

  @doc false
  def demo_loop(_pid, 0, _opts, _task_state_map, _progress_map), do: :ok

  def demo_loop(pid, ticks_left, opts, task_state_map, progress_map) do
    tasks = Keyword.get(opts, :tasks, [])

    {new_task_state_map, new_progress_map} =
      Enum.reduce(tasks, {task_state_map, progress_map}, fn task, {state_acc, prog_acc} ->
        update_task_progress(task, state_acc, prog_acc, pid, ticks_left)
      end)

    :timer.sleep(@tick_ms)
    demo_loop(pid, ticks_left - 1, opts, new_task_state_map, new_progress_map)
  end

  defp update_task_progress(task, state_acc, prog_acc, pid, ticks_left) do
    id = task.id
    current_state = Map.get(state_acc, id, :running)
    current_progress = Map.get(prog_acc, id, 0)

    cond do
      current_state == :failed ->
        {state_acc, prog_acc}

      current_state == :wait ->
        if :rand.uniform(3) == 1 do
          {Map.put(state_acc, id, :running), prog_acc}
        else
          {state_acc, prog_acc}
        end

      true ->
        advance_running_task(id, current_progress, state_acc, prog_acc, pid, ticks_left)
    end
  end

  defp advance_running_task(id, current_progress, state_acc, prog_acc, pid, ticks_left) do
    cond do
      :rand.uniform(100) == 1 and current_progress >= 60 ->
        MultiBar.error(pid, id, "Fallo simulado")
        Process.put({:task_state, id}, :failed)
        {Map.put(state_acc, id, :failed), prog_acc}

      :rand.uniform(33) == 1 and current_progress >= 20 and current_progress < 80 ->
        MultiBar.wait(pid, id, "Esperando recursos...")
        Process.put({:task_state, id}, :wait)
        {Map.put(state_acc, id, :wait), prog_acc}

      true ->
        increment = :rand.uniform(11) + 4
        new_progress = min(100, current_progress + increment)
        desc = description_for(id, ticks_left)
        MultiBar.progress(pid, id, new_progress, desc)
        {state_acc, Map.put(prog_acc, id, new_progress)}
    end
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

  @doc false
  def stdin_tty? do
    match?({:ok, _}, :io.columns())
  end

  @doc false
  def read_stdin_loop(pid) do
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
            process_stdin_line(pid, line)
            read_stdin_loop(pid)
        end
    end
  end

  defp process_stdin_line(pid, line) do
    case Data.parse_stdin_command(line) do
      {:ok, cmd} ->
        execute_stdin_command(pid, cmd)

      {:error, msg} ->
        IO.puts(:stderr, "Error: #{msg}")
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
end
