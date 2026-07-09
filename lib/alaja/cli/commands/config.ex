defmodule Alaja.CLI.Commands.Config do
  @moduledoc "DEPRECATED: The `alaja config` command has been removed. Use `alaja theme` for theme management."

  alias Alaja.Theme

  @doc false
  def install_theme_templates do
    # The original logic: write all Pote built-in templates
    Enum.each(Theme.templates(), fn name ->
      IO.write("  Writing #{name}.json ... ")

      case Theme.install_template(name) do
        :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
        {:error, reason} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(reason)}\e[0m")
      end
    end)

    # Then write Alaja's custom templates on top
    Enum.each(Alaja.Theme.CustomTemplates.all(), fn theme ->
      IO.write("  Writing #{theme.name}.json ... ")

      case Theme.install!(theme) do
        :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
        {:error, reason} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(reason)}\e[0m")
      end
    end)
  end

  @doc """
  Placeholder for a removed command.
  The function exists only so that dispatch tests can still call
  `Alaja.CLI.Commands.Config.run/1`.
  """
  @spec run(Keyword.t() | list()) :: :ok
  def run(_opts) do
    :ok
  end
end
