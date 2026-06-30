defmodule Alaja.CLI.Smoke.Case do
  @moduledoc """
  Base case for smoke tests.

  Smoke tests are **sacred**: they capture the rendered output of a real
  CLI invocation and compare it to a committed snapshot. They guard
  against visual regressions in the user-facing terminal output.

  ## How to update snapshots

  NEVER update a snapshot without explicit user review. To regenerate:

      $ mix alaja.snapshot --confirm

  This will overwrite `*.exs.snap` files for tests that failed. Each
  diff must be reviewed and committed manually.

  ## What they capture

  - The full stdout of `mix alaja <command> <args>`
  - With ANSI escape codes **stripped** (we test structure, not colors)
  - Normalized whitespace (no trailing spaces)
  - Compared to the committed `.exs.snap` file

  ## What they DON'T capture

  - Exact color codes (we strip ANSI)
  - TTY-specific behavior (we use a non-TTY subprocess)
  - Interactive prompts (use direct component tests for those)
  """

  use ExUnit.Case, async: false

  @doc """
  Runs an alaja CLI command as a subprocess and returns the stripped output.

  ## Options

    * `:timeout` — max ms to wait (default 30_000)
    * `:stdin` — string piped to stdin
    * `:env` — extra environment variables

  """
  @spec run_cli([String.t()], keyword()) :: {String.t(), String.t(), non_neg_integer()}
  def run_cli(args, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    stdin = Keyword.get(opts, :stdin, "")
    env = Keyword.get(opts, :env, [])

    project_root = alaja_project_root()

    full_env =
      [
        {"MIX_ENV", "test"},
        {"PATH", System.get_env("PATH") || ""},
        {"TERM", "dumb"},
        {"NO_COLOR", "1"}
      ]
      |> Kernel.++(env)

    cmd_args =
      ["run", "--no-mix-exs", "-e", "Alaja.CLI.main(System.argv())", "--"] ++ args

    task = System.cmd("elixir", cmd_args, [
      cd: project_root,
      env: full_env,
      stderr_to_stdout: true,
      stdin: stdin
    ])

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      {:exit, reason} -> flunk("CLI crashed: #{inspect(reason)}")
      nil -> flunk("CLI timed out after #{timeout}ms")
    end
  end

  @doc """
  Strips ANSI escape codes from output and normalizes whitespace.

  Removes:
    - All CSI sequences (`\e[...m`, `\e[...H`, `\e[K`, `\e[J`, etc.)
    - OSC sequences (`\e]...`)
    - Trailing whitespace per line
    - Carriage returns (`\r`)
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(output) do
    output
    |> String.replace(~r/\e\[[0-9;?]*[ -/]*[@-~]/, "")
    |> String.replace(~r/\e\][^\e]*\e\\/, "")
    |> String.replace("\r", "")
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  @doc """
  Compares actual output to committed snapshot.

  On mismatch:
    - Shows diff (first 1000 chars)
    - In CI without UPDATE_SNAPSHOTS: fails
    - Locally with `mix alaja.snapshot --confirm`: updates

  ## Options

    * `:snapshot` — override snapshot name (default: based on test name)
    * `:filter` — fn to filter the actual output before comparison (rare)
  """
  @spec assert_snapshot(String.t(), String.t(), keyword()) :: :ok
  def assert_snapshot(test_name, actual_output, opts \\ []) do
    snapshot_path = snapshot_path(test_name, opts[:snapshot])
    normalized_actual = normalize(actual_output)
    filter = Keyword.get(opts, :filter, & &1)
    actual = filter.(normalized_actual)

    cond do
      File.exists?(snapshot_path) ->
        expected = File.read!(snapshot_path) |> normalize()

        if actual == expected do
          :ok
        else
          write_diff(snapshot_path, expected, actual)
          flunk(snapshot_mismatch_message(snapshot_path, expected, actual))
        end

      System.get_env("UPDATE_SNAPSHOTS") == "1" ->
        File.mkdir_p!(Path.dirname(snapshot_path))
        File.write!(snapshot_path, normalized_actual)
        :ok

      true ->
        # No snapshot, no env var — write first run
        File.mkdir_p!(Path.dirname(snapshot_path))
        File.write!(snapshot_path, normalized_actual)
        flunk("Snapshot created at #{snapshot_path}. Re-run tests to verify.")
    end
  end

  @doc """
  Returns the absolute path of the snapshot file for a test.
  """
  @spec snapshot_path(String.t(), String.t() | nil) :: String.t()
  def snapshot_path(test_name, override \\ nil) do
    relative = override || Macro.underscore(test_name)
    Path.join([alaja_project_root(), "test", "alaja", "cli", "smoke", "snapshots", "#{relative}.exs.snap"])
  end

  # ---------------------------------------------------------------------------

  defp alaja_project_root do
    Application.app_dir(:alaja, "..")
    |> Path.expand()
    |> Path.absname()
  end

  defp write_diff(_path, expected, actual) do
    if File.identical?(expected, actual), do: :ok

    diff =
      [
        "--- expected",
        "+++ actual",
        ""
      ]
      |> Enum.concat(naive_diff(expected, actual))

    max_len = 4000
    truncated =
      if String.length(diff) > max_len do
        String.slice(diff, 0, max_len) <> "\n... [truncated]"
      else
        diff
      end

    IO.puts("\n=== SNAPSHOT DIFF ===")
    IO.puts(truncated)
    IO.puts("=== END DIFF ===\n")
  end

  defp naive_diff(a, b) do
    # Just show the actual vs expected side by side, simple approach
    a_lines = String.split(a, "\n")
    b_lines = String.split(b, "\n")
    max_lines = max(length(a_lines), length(b_lines))

    for i <- 0..(min(max_lines - 1, 50)) do
      a_line = Enum.at(a_lines, i) || ""
      b_line = Enum.at(b_lines, i) || ""

      cond do
        a_line == b_line -> "#{i}:  #{a_line}"
        true -> "#{i}: -#{a_line}\n#{i}: +#{b_line}"
      end
    end
  end

  defp snapshot_mismatch_message(path, expected, actual) do
    """
    Snapshot mismatch.

    File:  #{path}
    Expected: #{byte_size(expected)} bytes, #{length(String.split(expected, "\n"))} lines
    Actual:   #{byte_size(actual)} bytes, #{length(String.split(actual, "\n"))} lines

    If this change is intentional, run:

        $ mix alaja.snapshot --confirm

    Then review the diff and commit manually.
    """
  end
end