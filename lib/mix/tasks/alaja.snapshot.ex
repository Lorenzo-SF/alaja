defmodule Mix.Tasks.Alaja.Snapshot do
  @moduledoc """
  Manages smoke-test snapshots.

  Sacred snapshots are committed alongside tests and act as the visual
  regression net for alaja's CLI output. They must NEVER be updated
  without explicit human review.

  ## Usage

      # Re-run tests to see which ones fail (diff mode)
      $ mix test test/alaja/cli/smoke/

      # Regenerate snapshots (ONLY after reviewing the diffs)
      $ mix alaja.snapshot --confirm

      # List all snapshot files
      $ mix alaja.snapshot --list

  ## Workflow

  1. Make your change.
  2. Run `mix test test/alaja/cli/smoke/`.
  3. Tests FAIL with the diff printed.
  4. If the diff is correct, run `mix alaja.snapshot --confirm`.
  5. **Review the changes with `git diff test/alaja/cli/smoke/snapshots/`.**
  6. Commit manually with a descriptive message.

  ## Why manual review?

  Smoke snapshots are the visual contract of alaja. A diff might look
  fine but break real users (e.g. reordering rows, changing colors in
  subtle ways). Human review is mandatory.
  """

  use Mix.Task

  @shortdoc "Manage smoke-test snapshots"

  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          confirm: :boolean,
          list: :boolean
        ]
      )

    snapshots_dir = snapshot_dir()

    cond do
      opts[:list] ->
        list_snapshots(snapshots_dir)

      opts[:confirm] ->
        regenerate_all_snapshots(snapshots_dir)

      true ->
        print_help()
    end
  end

  defp print_help do
    Mix.shell().info("""
    mix alaja.snapshot — Manage smoke-test snapshots.

    Options:
      --confirm    Regenerate snapshots after reviewing diffs
      --list       List all snapshot files
    """)
  end

  defp snapshot_dir do
    Path.join([Mix.Project.project_file(), "..", "test", "alaja", "cli", "smoke", "snapshots"])
    |> Path.expand()
  end

  defp list_snapshots(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        snap_files = Enum.filter(files, &String.ends_with?(&1, ".exs.snap"))

        Mix.shell().info("Snapshots in #{dir}:")

        Enum.each(Enum.sort(snap_files), fn f ->
          size = File.stat!(Path.join(dir, f)).size
          Mix.shell().info("  #{f}  (#{size} bytes)")
        end)

        Mix.shell().info("\n#{length(snap_files)} snapshot(s) total.")

      _ ->
        Mix.shell().error("Snapshots directory not found: #{dir}")
    end
  end

  defp regenerate_all_snapshots(_dir) do
    Mix.shell().info("Running smoke tests with UPDATE_SNAPSHOTS=1 to regenerate...")
    Mix.shell().info("WARNING: this will overwrite existing snapshots without diff review.")

    {output, exit_code} =
      System.cmd(
        "mix",
        ["test", "test/alaja/cli/smoke/"],
        env: [{"UPDATE_SNAPSHOTS", "1"}, {"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    Mix.shell().info(output)

    if exit_code == 0 do
      Mix.shell().info("\nSnapshots regenerated.")
      Mix.shell().info("REVIEW the changes with: git diff test/alaja/cli/smoke/snapshots/")
      Mix.shell().info("Then commit manually.")
    else
      Mix.shell().error("\nTests failed even after regeneration. Check output above.")
    end
  end
end