defmodule Alaja.CLI.Commands.Action do
  @moduledoc """
  `alaja action` — Execute Alaja commands from JSON input.

  Accepts JSON from stdin, a file, or inline data and dispatches commands
  to `Alaja.CLI.main/1`. Supports single actions and batch operations.

  ## Examples

      echo '{"command": "success", "args": ["Done!"]}' | alaja action
      alaja action --file actions.json
      alaja action --data '{"command": "info", "args": ["Processing..."]}'
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
          stdin: :boolean
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
            process_data(data, global)

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
        # Try stdin (pipe mode)
        read_stdin()
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

  defp process_data(%{"actions" => actions} = data, _global) do
    verbose = Map.get(data, "verbose", false)
    quiet = Map.get(data, "quiet", false)

    actions
    |> Enum.sort_by(&Map.get(&1, "order", 0))
    |> Enum.each(fn action ->
      execute_action(action, verbose, quiet)
    end)

    :ok
  end

  defp process_data(data, _global) when is_map(data) do
    verbose = Map.get(data, "verbose", false)
    quiet = Map.get(data, "quiet", false)
    execute_action(data, verbose, quiet)
  end

  defp process_data(_data, _global) do
    IO.puts(:stderr, "Error: expected a JSON object or object with 'actions' array")
    exit({:shutdown, 1})
  end

  defp execute_action(action, verbose, quiet) do
    cmd = Map.get(action, "command") || Map.get(action, "action")
    args = Map.get(action, "args") || Map.get(action, "params") || []

    if is_nil(cmd) do
      IO.puts(:stderr, "  Error: missing 'command' field")
    else
      if cmd == "action" do
        IO.puts(:stderr, "  Error: recursive 'action' calls are not allowed")
        exit({:shutdown, 1})
      end

      full_args = build_args(cmd, args, verbose, quiet)
      Alaja.CLI.main(full_args)
    end
  end

  defp build_args(cmd, args, verbose, quiet) do
    cmd_parts =
      if String.contains?(cmd, " ") do
        String.split(cmd)
      else
        [cmd]
      end

    string_args = Enum.map(args, &to_string/1)
    extra = cmd_parts ++ string_args

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
    IO.puts("  operations with ordered execution.")
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
        ["--stdin", "-s", "boolean", "Force reading from stdin"]
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

    # With global options
      alaja action --data '{"command":"message","args":["Hello"],"verbose":true}'

    # Force stdin mode
      alaja action --stdin < commands.json
    """)

    IO.puts("")
    :ok
  end
end
