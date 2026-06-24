defmodule Alaja.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :ok = register_pote_theme_resolver()

    children = []

    opts = [strategy: :one_for_one, name: Alaja.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Bridge Pote's theme lookup to Alaja's active theme.
  #
  # Without this, `Pote.Orchestrator.parse_color("theme:<key>")` falls
  # back to Pote's hardcoded `@default_colors` palette, ignoring
  # whatever theme the user has selected with `alaja config theme set`.
  defp register_pote_theme_resolver do
    Pote.put_theme_resolver(fn key ->
      case Alaja.Config.lookup_theme_color(key) do
        {:ok, _} = result -> result
        :error -> :not_found
      end
    end)
  end
end
