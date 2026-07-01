defmodule Alaja.SmokeCase do
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

  defmacro __using__(opts) do
    quote do
      use ExUnit.Case, unquote(opts)
      import ExUnit.Assertions
      import Alaja.SmokeCase
    end
  end

  @ansi_csi_regex ~r/\x1b\[[0-9;]*[a-zA-Z]/
  @ansi_osc_regex ~r/\x1b\][^\x07]*\x07/

  @doc """
  Runs an alaja CLI command as a subprocess and returns the stripped output.

  Internally shells out to:
      mix run --no-start --eval "Alaja.CLI.main(System.argv())" -- <args>

  `--no-start` avoids re-booting the OTP applications while still loading
  the host project's compiled artifacts (including `Alaja.*` modules).

  ## Options

    - `:timeout` — wall-clock timeout in ms (default 30_000)
    - `:stdin` — payload to feed via stdin, or `nil` (default) to skip piping
    - `:env` — additional environment variables to add

  ## Note

  On Elixir 1.19+ `System.cmd/3` rejects `stdin: ""` with `ArgumentError`,
  so we omit the `:stdin` key entirely when no payload is provided. We
  also wrap the call in `Task.async` so we get a `%Task{}` that we can
  control with `Task.yield/2` (Elixir 1.19's stricter type checking
  rejects treating a plain `{stdout, stderr, code}` tuple as a Task).
  """
  @spec run_cli([String.t()], keyword()) :: {String.t(), String.t(), non_neg_integer()}
  def run_cli(args, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    stdin = Keyword.get(opts, :stdin)
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
      [
        "run",
        "--no-start",
        "--no-deps-check",
        "--no-compile",
        "--eval",
        "Alaja.CLI.main(System.argv())",
        "--"
      ]
      ++ args

    base_opts = [cd: project_root, env: full_env, stderr_to_stdout: true]
    cmd_opts = if stdin == nil, do: base_opts, else: Keyword.put(base_opts, :stdin, stdin)

    task = Task.async(fn -> System.cmd("mix", cmd_args, cmd_opts) end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      # Elixir 1.19's `System.cmd/3` returns a 2-tuple `{output, exit_status}`
      # when `stderr_to_stdout: true` is set (the second tuple element is
      # collapsed since stderr is already merged into stdout).
      {:ok, {combined, exit_code}} -> {combined, "", exit_code}
      {:exit, reason} -> raise "CLI crashed: #{inspect(reason)}"
      nil -> raise "CLI timed out after #{timeout}ms"
    end
  end

  @doc """
  Strips ANSI escape codes from output and normalizes whitespace.
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(output) do
    output
    |> String.replace(@ansi_csi_regex, "")
    |> String.replace(@ansi_osc_regex, "")
    |> String.replace("\r", "")
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  @doc """
  Compares actual output to committed snapshot.
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

        cond do
          actual == expected ->
            :ok

          System.get_env("UPDATE_SNAPSHOTS") == "1" ->
            File.mkdir_p!(Path.dirname(snapshot_path))
            File.write!(snapshot_path, normalized_actual)
            :ok

          true ->
            write_diff(snapshot_path, expected, actual)
            raise snapshot_mismatch_message(snapshot_path, expected, actual)
        end

      true ->
        File.mkdir_p!(Path.dirname(snapshot_path))
        File.write!(snapshot_path, normalized_actual)
        raise "Snapshot created at #{snapshot_path}. Re-run tests to verify."
    end
  end

  @doc """
  Returns the absolute path of the snapshot file for a test.
  """
  @spec snapshot_path(String.t(), String.t() | nil) :: String.t()
  def snapshot_path(test_name, override \\ nil) do
    relative = override || Macro.underscore(test_name)

    Path.join([
      alaja_project_root(),
      "test",
      "alaja",
      "cli",
      "smoke",
      "snapshots",
      "#{relative}.exs.snap"
    ])
  end

  # ---------------------------------------------------------------------------

  defp alaja_project_root do
    # `_build/test/lib/alaja/ebin` is loaded as the alaja app dir; the
    # project root is two segments up regardless of the cwd mix was
    # launched from. We resolve via the file system link to handle
    # both symlinked workspaces and direct checkouts uniformly.
    deps_dir = Application.app_dir(:alaja)
    deps_dir
    |> Path.expand()
    |> Path.absname()
    |> then(fn path ->
      # path looks like `<root>/_build/test/lib/alaja`. Walk up until
      # we find a directory containing a `mix.exs` whose `app:` matches
      # `:alaja`. Two levels is enough in our setup.
      path
      |> Path.dirname()            # .../lib/alaja  ->  .../lib
      |> Path.dirname()            # .../lib        ->  .../test
      |> Path.dirname()            # .../test       ->  .../_build
      |> Path.dirname()            # .../_build     ->  project root
    end)
  end

  defp write_diff(_path, expected, actual) do
    # Compare as binaries (the strings have been normalised upstream, so == is enough).
    if expected == actual, do: :ok

    diff =
      ["--- expected", "+++ actual", ""]
      |> Enum.concat(naive_diff(expected, actual))

    max_len = 4000

    truncated =
      diff_bin = IO.iodata_to_binary(diff)

      if String.length(diff_bin) > max_len do
        String.slice(diff_bin, 0, max_len) <> "\n... [truncated]"
      else
        diff_bin
      end

    IO.puts("\n=== SNAPSHOT DIFF ===")
    IO.puts(truncated)
    IO.puts("=== END DIFF ===\n")
  end

  defp naive_diff(a, b) do
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