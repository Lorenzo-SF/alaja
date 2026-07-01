defmodule Alaja.CLI.Commands.Action do
  @moduledoc """
  `alaja action` — Execute Alaja commands from JSON input.

  Accepts JSON from stdin, a file, or inline data and dispatches commands
  to `Alaja.CLI.exec/1` (in-process). Supports single actions and batch
  operations.

  ## Performance

  Batch execution uses `Alaja.CLI.exec/1` which **does not re-start the
  application stack** for each element. This makes batch actions
  dramatically faster than the historical implementation (which called
  `Alaja.CLI.main/1` and paid the boot cost on every invocation).

  ## Examples

      echo '{"command": "success", "args": ["Done!"]}' | alaja action
      alaja action --file actions.json
      alaja action --data '{"command": "info", "args": ["Processing..."]}'
      alaja action --data '{"actions":[...]}' --stop-on-error
      alaja action --data '{"actions":[...]}' --parallel 4
      alaja action --data '{"actions":[...]}' --dry-run
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Header, Separator, Table}

  @doc """
  Runs the `alaja action` command.
  """
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          file: :string,
          data: :string,
          stdin: :boolean,
          parallel: :integer,
          stop_on_error: :boolean,
          dry_run: :boolean
        ],
        aliases: [
          f: :file,
          d: :data,
          s: :stdin
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      execute(opts, global)
    end
  end

  defp execute(opts, global) do
    case get_json(opts) do
      {:ok, json_str} ->
        case Jason.decode(json_str) do
          {:ok, data} ->
            process_data(data, global, opts)

          {:error, error} ->
            IO.puts(:stderr, "Error: invalid JSON: #{error}")
            exit({:shutdown, 1})
        end

      {:error, reason} ->
        IO.puts(:stderr, "Error: #{reason}")
        exit({:shutdown, 1})
    end
  end

  # ─── JSON source resolution ───────────────────────────────────────────────

  defp get_json(opts) do
    cond do
      Keyword.get(opts, :stdin, false) ->
        read_stdin()

      Keyword.get(opts, :file) ->
        read_file(Keyword.get(opts, :file))

      Keyword.get(opts, :data) ->
        {:ok, Keyword.get(opts, :data)}

      true ->
        # Try stdin (pipe mode) only when interactive stdin is available.
        # In TTY mode this would hang indefinitely waiting for EOF.
        if io_interactive?() do
          {:error, "no input: pass --file, --data, or pipe JSON via stdin"}
        else
          read_stdin()
        end
    end
  end

  defp io_interactive? do
    case :io.getopts() do
      {:error, _} -> false
      opts -> Keyword.get(opts, :binary, false) == false and not interactive_tty?()
    end
  end

  defp interactive_tty? do
    case :io.getopts() do
      {:error, _} -> false
      _ -> System.get_env("TERM") != "dumb" and not has_input_pipe?()
    end
  end

  defp has_input_pipe? do
    # Heuristic: if stdin is connected to a tty, no pipe. We check via
    # Erlang's :standard_io because IO.respond?/0 is unreliable across
    # OTP versions.
    case :erlang.port_info(:standard_io, :input) do
      {:input, "fd:0"} ->
        # In TTY if `tty -s` returns 0 (POSIX). Skip the OS check
        # and rely on TERM=dumb (smoke tests) to disable stdin reads.
        not (System.get_env("TERM") == "dumb")

      _ ->
        false
    end
  end

  defp read_stdin do
    case IO.binread(:stdio, :eof) do
      :eof -> {:error, "No data received from stdin"}
      data when is_binary(data) and data == "" -> {:error, "No data received from stdin"}
      data -> {:ok, String.trim(data)}
    end
  end

  defp read_file(path) do
    if File.exists?(path) do
      case File.read(path) do
        {:ok, content} -> {:ok, content}
        {:error, reason} -> {:error, "Cannot read '#{path}': #{reason}"}
      end
    else
      {:error, "File not found: '#{path}'"}
    end
  end

  # ─── Data processing ──────────────────────────────────────────────────────

  defp process_data(%{"actions" => actions} = data, _global, opts) do
    verbose = Map.get(data, "verbose", false)
    quiet = Map.get(data, "quiet", false)
    parallel = Keyword.get(opts, :parallel, 1)
    stop_on_error = Keyword.get(opts, :stop_on_error, false)
    dry_run = Keyword.get(opts, :dry_run, false)

    actions
    |> Enum.sort_by(&Map.get(&1, "order", 0))
    |> run_actions(parallel, stop_on_error, dry_run, verbose, quiet)

    :ok
  end

  defp process_data(data, _global, opts) when is_map(data) do
    verbose = Map.get(data, "verbose", false)
    quiet = Map.get(data, "quiet", false)
    dry_run = Keyword.get(opts, :dry_run, false)

    if dry_run do
      IO.puts("Would execute: #{inspect(data)}")
    else
      execute_action(data, verbose, quiet)
    end

    :ok
  end

  defp process_data(_data, _global, _opts) do
    IO.puts(:stderr, "Error: expected a JSON object or object with 'actions' array")
    exit({:shutdown, 1})
  end

  defp run_actions(actions, 1, false, false, verbose, quiet) do
    # Fast path: sequential, no stop-on-error, no dry-run. The common case.
    Enum.each(actions, fn action ->
      execute_action(action, verbose, quiet)
    end)
  end

  defp run_actions(actions, parallel, stop_on_error, _dry_run, verbose, quiet)
       when parallel > 1 do
    _ =
      actions
      |> Task.async_stream(
        fn action -> {action, execute_action(action, verbose, quiet)} end,
        max_concurrency: parallel,
        ordered: false,
        on_timeout: :kill_task
      )
      |> Enum.reduce_while(0, fn
        {:ok, {_, :ok}}, count ->
          {:cont, count + 1}

        {:ok, {action, error}}, count ->
          handle_stream_error(action, error, stop_on_error, count)

        {:exit, reason}, count ->
          if stop_on_error do
            {:halt, count}
          else
            IO.puts(:stderr, "Warning: action exited: #{inspect(reason)}")
            {:cont, count + 1}
          end
      end)

    :ok
  end

  defp run_actions(actions, _parallel, stop_on_error, dry_run, verbose, quiet) do
    _ =
      Enum.reduce_while(actions, 0, fn action, count ->
        if dry_run do
          IO.puts("Would execute: #{inspect(action)}")
          {:cont, count + 1}
        else
          process_action_result(action, verbose, quiet, stop_on_error, count)
        end
      end)

    :ok
  end

  defp process_action_result(action, verbose, quiet, stop_on_error, count) do
    case execute_action_safe(action, verbose, quiet) do
      :ok ->
        {:cont, count + 1}

      {:error, reason} ->
        handle_action_error(action, reason, stop_on_error, count)
    end
  end

  defp handle_stream_error(action, error, stop_on_error, count) do
    if stop_on_error do
      IO.puts(:stderr, "Error in action #{inspect(action)}: #{inspect(error)}")
      {:halt, count}
    else
      IO.puts(:stderr, "Warning: action #{inspect(action)} failed: #{inspect(error)}")
      {:cont, count + 1}
    end
  end

  defp handle_action_error(action, reason, stop_on_error, count) do
    if stop_on_error do
      IO.puts(:stderr, "Error in action #{inspect(action)}: #{inspect(reason)}")
      {:halt, count}
    else
      IO.puts(:stderr, "Warning: action #{inspect(action)} failed: #{inspect(reason)}")
      {:cont, count + 1}
    end
  end

  defp execute_action_safe(action, verbose, quiet) do
    execute_action(action, verbose, quiet)
  rescue
    e -> {:error, Exception.message(e)}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp execute_action(action, verbose, quiet) do
    cmd = Map.get(action, "command") || Map.get(action, "action")
    args = Map.get(action, "args") || Map.get(action, "params") || []

    cond do
      is_nil(cmd) ->
        IO.puts(:stderr, "  Error: missing 'command' field")

      String.downcase(to_string(cmd)) == "action" ->
        IO.puts(:stderr, "  Error: recursive 'action' calls are not allowed")
        exit({:shutdown, 1})

      true ->
        full_args = build_args(cmd, args, verbose, quiet)
        Alaja.CLI.exec(full_args)
    end
  end

  defp build_args(cmd, args, verbose, quiet) do
    cmd_str = to_string(cmd)
    string_args = Enum.map(args, &to_string/1)

    extra =
      if String.contains?(cmd_str, " ") do
        [cmd_str | string_args]
      else
        [cmd_str | string_args]
      end

    extra =
      if verbose do
        extra ++ ["--verbose"]
      else
        extra
      end

    if quiet, do: extra ++ ["--quiet"], else: extra
  end

  # ─── Help ─────────────────────────────────────────────────────────────────

  @doc """
  Prints help for the `alaja action` command.
  """
  @spec help() :: :ok
  def help do
    Header.print("Alaja Action",
      subtitle: "Execute Alaja commands from JSON input",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Execute Alaja commands from JSON input. Accepts JSON from stdin,")
    IO.puts("  a file, or inline data. Supports single actions and batch")
    IO.puts("  operations with ordered execution and parallel dispatch.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  echo '<json>' | alaja action")
    IO.puts("  alaja action --file <path>")
    IO.puts("  alaja action --data <json>")
    IO.puts("  alaja action --stdin")
    IO.puts("")

    Separator.print("OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Alias", "Type", "Description"],
      rows: [
        ["--file PATH", "-f", "string", "Read JSON from a file"],
        ["--data JSON", "-d", "string", "Inline JSON string"],
        ["--stdin", "-s", "boolean", "Force reading from stdin"],
        ["--parallel N", "", "integer", "Run N actions in parallel (default 1)"],
        ["--stop-on-error", "", "boolean", "Halt batch on first error (default false)"],
        ["--dry-run", "", "boolean", "Print actions without executing (default false)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("SOURCE PRIORITY", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  --stdin > --file > --data > (implicit stdin)")
    IO.puts("")

    Separator.print("JSON SCHEMA", char: "━", width: 50, color: {0, 180, 216})

    IO.puts("  Single action:")

    IO.puts(
      "  #{String.replace(~s({\n    "command": "success",\n    "args": ["Done!"]\n  }), "  ", "")}"
    )

    IO.puts("")

    IO.puts("  Batch actions:")

    IO.puts(
      "  #{String.replace(~s({\n    "verbose": true,\n    "quiet": false,\n    "actions": [\n      {"command": "info", "args": ["Step 1"], "order": 0},\n      {"command": "success", "args": ["Complete"], "order": 1}\n    ]\n  }), "  ", "")}"
    )

    IO.puts("")

    Separator.print("FIELD ALIASES", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Field", "Alias", "Description"],
      rows: [
        ["command", "action", "Command to execute"],
        ["args", "params", "Arguments for the command"],
        ["order", "", "Execution order (batch mode)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("EXAMPLES", char: "━", width: 50, color: {0, 180, 216})

    IO.puts(~s"""
    # Pipe JSON to action
      echo '{"command":"success","args":["OK"]}' | alaja action

    # From a file
      alaja action --file ./pipeline.json

    # Inline JSON data
      alaja action --data '{"command":"info","args":["Processing..."]}'

    # Using field aliases
      alaja action --data '{"action":"warning","params":["Low disk space"]}'

    # Batch actions with ordering
      alaja action --data '{"actions":[{"command":"info","args":["Step 1"],"order":0},{"command":"success","args":["Done"],"order":1}]}'

    # Parallel batch (4 concurrent actions)
      alaja action --data '{"actions":[...]}' --parallel 4

    # Stop on first error
      alaja action --data '{"actions":[...]}' --stop-on-error

    # Dry run: validate the pipeline without executing
      alaja action --data '{"actions":[...]}' --dry-run

    # With global options
      alaja action --data '{"command":"message","args":["Hello"],"verbose":true}'

    # Force stdin mode
      alaja action --stdin < commands.json
    """)

    IO.puts("")
    :ok
  end
end
