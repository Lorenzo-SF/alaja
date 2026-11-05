defmodule Alaja.CLI.ErrorHandler do
  @moduledoc """
  Error handling for CLI commands.

  Provides formatted error messages, suggestions,
  and appropriate exit codes.
  """

  require Logger

  @doc "Handles unknown command by showing suggestions."
  @spec unknown_command(String.t(), [map()]) :: {:error, :unknown_command}
  def unknown_command(command, commands) do
    log_warning("unknown command '#{command}'")
    Alaja.Output.write_error("Error: unknown command '#{command}'")

    suggestions = suggest(command, available_names(commands))

    unless suggestions == [] do
      Alaja.Output.write_error("\nDid you mean?")
      Enum.each(suggestions, fn s -> Alaja.Output.write_error("  #{s}") end)
    end

    print_available(commands)
    {:error, :unknown_command}
  end

  @doc "Shows error when no command is given."
  @spec no_command([map()]) :: {:error, :no_command}
  def no_command(commands) do
    log_warning("no command specified")
    Alaja.Output.write_error("Error: no command specified")
    print_available(commands)
    {:error, :no_command}
  end

  @doc "Shows error when a command has no run handler."
  @spec no_handler(String.t()) :: {:error, :no_handler}
  def no_handler(name) do
    log_warning("command '#{name}' has no handler defined")
    Alaja.Output.write_error("Error: command '#{name}' has no handler defined")
    {:error, :no_handler}
  end

  @doc "Prints flag validation errors and exits."
  @spec flag_errors([String.t()]) :: {:error, atom()}
  def flag_errors(errors) do
    log_warning("invalid options")
    Alaja.Output.write_error("Error: invalid options")
    Enum.each(errors, fn e -> Alaja.Output.write_error("  #{e}") end)
    {:error, :handler}
  end

  @doc "Shows error for missing required positional arguments."
  @spec missing_args(String.t(), [atom()]) :: {:error, atom()}
  def missing_args(command_name, missing_names) do
    args = Enum.map_join(missing_names, ", ", &"<#{&1}>")
    log_warning("command '#{command_name}' requires: #{args}")
    Alaja.Output.write_error("Error: command '#{command_name}' requires: #{args}")
    {:error, :handler}
  end

  @doc "Prints a formatted error message for the CLI."
  @spec format_error(String.t(), String.t()) :: {:error, atom()}
  def format_error(title, detail) do
    log_warning("#{title}: #{detail}")
    Alaja.Output.write_error("Error: #{title}")
    unless detail == "", do: Alaja.Output.write_error("  #{detail}")
    {:error, :handler}
  end

  # ─── Private ──────────────────────────────────────────────────────

  defp log_warning(msg) do
    if Alaja.Config.get(:error_handler_logger, false) do
      Logger.warning(fn -> msg end)
    end
  end

  defp print_available(commands) do
    unless commands == [] do
      Alaja.Output.write_error("\nAvailable commands:")
      Enum.each(commands, fn cmd -> print_cmd(cmd, "  ") end)
    end
  end

  defp print_cmd(%{name: name, description: desc, subcommands: subs}, prefix) do
    Alaja.Output.write_error("#{prefix}#{String.pad_trailing(name, 20)} #{desc}")

    unless subs == %{} or (is_list(subs) and subs == []) do
      sub_list = if is_map(subs), do: Map.values(subs), else: subs
      Enum.each(sub_list, fn s -> print_cmd(s, prefix <> "  ") end)
    end
  end

  defp print_cmd(cmd, prefix) when is_tuple(cmd) do
    {name, sub} = cmd

    if is_map(sub) do
      Alaja.Output.write_error("#{prefix}#{String.pad_trailing(name, 18)} #{sub.description}")
    end
  end

  defp available_names(commands) do
    Enum.flat_map(commands, fn
      %{name: name, subcommands: subs} when map_size(subs) > 0 ->
        [name | Enum.map(subs, fn {k, _v} -> "#{name} #{k}" end)]

      %{name: name} ->
        [name]
    end)
  end

  @doc false
  def suggest(input, options) do
    input = String.downcase(input)

    options
    |> Enum.filter(fn opt ->
      String.jaro_distance(input, String.downcase(opt)) > 0.6
    end)
    |> Enum.sort_by(fn opt ->
      -String.jaro_distance(input, String.downcase(opt))
    end)
    |> Enum.take(3)
  end
end
