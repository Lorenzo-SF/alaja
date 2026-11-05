defmodule Alaja.CLI.NoColor do
  @moduledoc """
  Bridge between the CLI colour flags and `Alaja.Config.color_enabled?/0`.

  The flags must reach the Application env before any command runs because
  the help renderer, theme resolver, and printer all query
  `Alaja.Config.color_enabled?/0` (or `:no_color` directly) at render time.
  A flag that only reached the printer level would leave `Alaja.Theme`
  still reporting colour as enabled.

  ## Flags handled

      * `--no-color`          → `:alaja, :no_color` = `true`
      * `--force-color`       → `:alaja, :color`     = `:always`
      * `--force-colour`      → idem (British spelling)

  ## Priority

  The resulting resolution order — highest wins — is:

      1. `--force-color` / `--no-color` CLI flags, via `:alaja, :color`.
      2. `NO_COLOR` environment variable (set by `Config.overlay_env_vars/1`).
      3. `IO.ANSI.enabled?/0` when `:elixir, :ansi_enabled` was set explicitly.
      4. `Alaja.Terminal.tty?/0`.

  `:no-color` does not force-enable colour when stdout is a TTY; that is
  what `--force-color` is for, and pinning it separately here is what keeps
  the two flags from changing long-standing semantics for each other.
  """

  @force_flags ["--force-color", "--force-colour"]

  @doc """
  Parses `argv` and syncs the colour flags into the Application env, so
  that subsequent `Alaja.Config.color_enabled?/0` calls agree with them.

  `--force-color` writes `:alaja, :color` = `:always`, which is the one key
  `color_enabled?/0` consults before anything else. Before this, the flag
  parsed into `Alaja.CLI.GlobalOpts` and stopped there: nothing ever read
  it back, so a binary that rendered monochrome could not be coaxed back
  into colour by any flag at all.

  Idempotent: calling it twice with the same argv has the same effect.
  """
  @spec sync([String.t()]) :: :ok
  def sync(argv) when is_list(argv) do
    if "--no-color" in argv do
      Application.put_env(:alaja, :no_color, true)
    end

    if Enum.any?(@force_flags, &(&1 in argv)) do
      Application.put_env(:alaja, :color, :always)
    end

    :ok
  end
end
