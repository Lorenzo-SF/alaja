defmodule Alaja.Theme.Bootstrap do
  @moduledoc """
  First-run setup for the user's theme directory.

  On a clean machine `~/.config/alaja/` doesn't exist yet, so any CLI
  command that consults the active theme (e.g. `alaja theme list`,
  `alaja separator --color "theme:primary"`, or any test of those
  paths) would see an empty palette and fail with `"No themes found.
  Run alaja theme init first."`.

  `ensure_installed/0` is **idempotent** — it only installs the
  built-in templates and the `catppuccin` theme defaults when neither
  `~/.config/alaja/alaja.conf` nor any installed theme exists. Once
  the user has done any of `alaja theme init`, `alaja theme set`, or
  used `alaja` once interactively (which runs the showcase), the
  guard short-circuits and the function is a no-op.

  Called from `Alaja.Application.start/2` so any code that runs inside
  `mix test` (and therefore under `mix test --cover` in CI) gets a
  populated theme directory without each test having to bootstrap
  explicitly. The showcase still calls it as a belt-and-braces guard
  for `mix run --no-start` workflows.
  """

  alias Alaja.{Config, Theme}

  @default_theme "catppuccin"

  @doc """
  Idempotent first-run setup. Safe to call from `Application.start/2`
  on every boot — does nothing once the theme directory is populated.
  """
  @spec ensure_installed() :: :ok
  def ensure_installed do
    if needs_install?() do
      File.mkdir_p!(Theme.storage_dir())
      Enum.each(Theme.templates(), &Theme.install_template/1)
      Enum.each(Theme.CustomTemplates.all(), &Theme.install!/1)
      Theme.activate(@default_theme)
      Config.set(:theme_active, @default_theme)
    end

    :ok
  end

  defp needs_install? do
    not File.exists?(alaja_conf()) or Theme.list() == []
  end

  defp alaja_conf do
    Path.join([System.user_home!(), ".config", "alaja", "alaja.conf"])
  end
end
