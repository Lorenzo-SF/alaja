defmodule Alaja.CLI.NoColor do
  @moduledoc """
  Bridge between the CLI flag `--no-color` and `Alaja.Config.color_enabled?/0`.

  The CLI flag must reach the Application env before any command runs because
  the help renderer, theme resolver, and printer all query
  `Alaja.Config.color_enabled?/0` (or `:no_color` directly) at render time.

  ## Priority

  The resulting resolution order — highest wins — is:

      1. `--no-color` CLI flag (sets `:no_color` to `true`).
      2. `NO_COLOR` environment variable (set by Config.overlay_env_vars/1,
         also to `true`).
      3. `IO.ANSI.enabled?/0` (the default fallback in Config.color_enabled?/0).

  `:no-color` does NOT force-enable colour when stdout is a TTY; that is
  the job of the `--color` flag, which is intentionally NOT mirrored here
  because it would change long-standing semantics.
  """

  @doc """
  Parses `argv`, and if `--no-color` is present, sets
  `Application.put_env(:alaja, :no_color, true)` so subsequent
  `Alaja.Config.color_enabled?/0` calls return `false`.

  Idempotent: calling it twice with the same argv has the same effect.
  """
  @spec sync([String.t()]) :: :ok
  def sync(argv) when is_list(argv) do
    if "--no-color" in argv do
      Application.put_env(:alaja, :no_color, true)
    end

    :ok
  end
end
