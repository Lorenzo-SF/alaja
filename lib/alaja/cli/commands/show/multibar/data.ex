defmodule Alaja.CLI.Commands.Show.Multibar.Data do
  @moduledoc false

  @doc false
  @spec parse_tasks(String.t()) :: {:ok, list(map())} | {:error, String.t()}
  def parse_tasks(tasks_str) do
    tasks_str
    |> String.split(";", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> parse_tasks_entries()
  end

  defp parse_tasks_entries([]) do
    {:error, "--tasks is required (format: id:label;id:label)"}
  end

  defp parse_tasks_entries(parts) do
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

  defp parse_task_entry(entry) do
    case String.split(entry, ":", parts: 2) do
      [id_str, label] -> build_task_from_parsed(id_str, label, entry)
      _ -> {:error, "task entry '#{entry}' must be in id:label format"}
    end
  end

  defp build_task_from_parsed(id_str, label, entry) do
    id_str = String.trim(id_str)
    label = String.trim(label)

    case validate_task_parts(id_str, label, entry) do
      :ok -> create_task(id_str, label)
      {:error, msg} -> {:error, msg}
    end
  end

  defp validate_task_parts(id_str, label, entry) do
    cond do
      id_str == "" ->
        {:error, "task id cannot be empty in '#{entry}'"}

      label == "" ->
        {:error, "task label cannot be empty in '#{entry}'"}

      not valid_id?(id_str) ->
        {:error, "task id '#{id_str}' must be lowercase alphanumeric (got: '#{id_str}')"}

      true ->
        :ok
    end
  end

  defp create_task(id_str, label) do
    {:ok, atom} = safe_atom(id_str)
    {:ok, %{id: atom, label: label}}
  end

  defp valid_id?(id_str) do
    String.match?(id_str, ~r/^[a-z][a-z0-9]*$/)
  end

  @doc false
  @spec parse_border(String.t()) :: atom()
  def parse_border("normal"), do: :normal
  def parse_border("rounded"), do: :rounded
  def parse_border("double"), do: :double
  def parse_border("none"), do: :none

  def parse_border(other) do
    IO.puts(:stderr, "Warning: --border '#{other}' not valid, using 'rounded'")
    :rounded
  end

  @doc false
  @spec parse_stdin_command(String.t()) :: {:ok, tuple()} | {:error, String.t()}
  def parse_stdin_command(line) do
    parts = String.split(line, " ", parts: 4) |> Enum.map(&String.trim/1)
    [cmd | args] = parts

    case cmd do
      "progress" -> parse_progress(args)
      "success" -> parse_success(args)
      "error" -> parse_error(args)
      "wait" -> parse_wait(args)
      "info" -> parse_info(args)
      _ -> {:error, "Unknown command '#{cmd}'"}
    end
  end

  defp parse_progress([task_id, pct_str]) do
    with {:ok, pct} <- parse_pct(pct_str),
         {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:progress, atom, pct, nil}}
    end
  end

  defp parse_progress([task_id, pct_str, desc]) do
    with {:ok, pct} <- parse_pct(pct_str),
         {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:progress, atom, pct, desc}}
    end
  end

  defp parse_progress(_args) do
    {:error, "progress <task_id> <pct> [description]"}
  end

  defp parse_success([task_id]) do
    with {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:status, atom, :success, nil}}
    end
  end

  defp parse_success([task_id, msg]) do
    with {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:status, atom, :success, msg}}
    end
  end

  defp parse_success(_args) do
    {:error, "success <task_id> [message]"}
  end

  defp parse_error([task_id]) do
    with {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:status, atom, :error, nil}}
    end
  end

  defp parse_error([task_id, msg]) do
    with {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:status, atom, :error, msg}}
    end
  end

  defp parse_error(_args) do
    {:error, "error <task_id> [message]"}
  end

  defp parse_wait([task_id]) do
    with {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:status, atom, :wait, nil}}
    end
  end

  defp parse_wait([task_id, reason]) do
    with {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:status, atom, :wait, reason}}
    end
  end

  defp parse_wait(_args) do
    {:error, "wait <task_id> [reason]"}
  end

  defp parse_info([task_id, msg]) do
    with {:ok, atom} <- safe_atom(task_id) do
      {:ok, {:info, atom, msg}}
    end
  end

  defp parse_info(_args) do
    {:error, "info <task_id> <message>"}
  end

  defp safe_atom(task_id) do
    # Dynamic atom: task IDs come from the user, so we cannot use
    # String.to_existing_atom/1 (which would crash for new IDs).
    # The set of atoms created is bounded by the set of user-supplied IDs
    # and persists for the application lifetime.
    # credo:disable-for-next-line
    {:ok, String.to_atom(task_id)}
  end

  defp parse_pct(str) do
    case Integer.parse(str) do
      {pct, _} when pct >= 0 and pct <= 100 -> {:ok, pct}
      {_pct, _} -> {:error, "percentage must be 0-100"}
      :error -> {:error, "invalid percentage value"}
    end
  end
end
