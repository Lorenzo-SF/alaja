defmodule Alaja.CLI.ErrorHandler do
  @moduledoc """
  Error handling for CLI commands.

  Provides formatted error messages, suggestions,
  and appropriate exit codes.
  """

  @doc "Handles unknown command by showing suggestions."
  @spec unknown_command(String.t(), [map()]) :: no_return()
  def unknown_command(command, commands) do
    IO.puts(:stderr, "Error: unknown command '#{command}'")

    suggestions = suggest(command, available_names(commands))

    unless suggestions == [] do
      IO.puts(:stderr, "\nDid you mean?")
      Enum.each(suggestions, fn s -> IO.puts(:stderr, "  #{s}") end)
    end

    print_available(commands)
    System.halt(1)
  end

  @doc "Shows error when no command is given."
  @spec no_command([map()]) :: no_return()
  def no_command(commands) do
    IO.puts(:stderr, "Error: no command specified")
    print_available(commands)
    System.halt(1)
  end

  @doc "Shows error when a command has no run handler."
  @spec no_handler(String.t()) :: no_return()
  def no_handler(name) do
    IO.puts(:stderr, "Error: command '#{name}' has no handler defined")
    System.halt(1)
  end

  @doc "Prints flag validation errors and exits."
  @spec flag_errors([String.t()]) :: no_return()
  def flag_errors(errors) do
    IO.puts(:stderr, "Error: invalid options")
    Enum.each(errors, fn e -> IO.puts(:stderr, "  #{e}") end)
    System.halt(1)
  end

  @doc "Shows error for missing required positional arguments."
  @spec missing_args(String.t(), [atom()]) :: no_return()
  def missing_args(command_name, missing_names) do
    args = Enum.map_join(missing_names, ", ", &"<#{&1}>")
    IO.puts(:stderr, "Error: command '#{command_name}' requires: #{args}")
    System.halt(1)
  end

  @doc "Prints a formatted error message for the CLI."
  @spec format_error(String.t(), String.t()) :: no_return()
  def format_error(title, detail) do
    IO.puts(:stderr, "Error: #{title}")
    unless detail == "", do: IO.puts(:stderr, "  #{detail}")
    System.halt(1)
  end

  # ─── Private ──────────────────────────────────────────────────────

  defp print_available(commands) do
    unless commands == [] do
      IO.puts(:stderr, "\nAvailable commands:")
      Enum.each(commands, fn cmd -> print_cmd(cmd, "  ") end)
    end
  end

  defp print_cmd(%{name: name, description: desc, subcommands: subs}, prefix) do
    IO.puts(:stderr, "#{prefix}#{String.pad_trailing(name, 20)} #{desc}")

    unless subs == %{} or (is_list(subs) and subs == []) do
      sub_list = if is_map(subs), do: Map.values(subs), else: subs
      Enum.each(sub_list, fn s -> print_cmd(s, prefix <> "  ") end)
    end
  end

  defp print_cmd(cmd, prefix) when is_tuple(cmd) do
    {name, sub} = cmd

    if is_map(sub) do
      IO.puts(:stderr, "#{prefix}#{String.pad_trailing(name, 18)} #{sub.description}")
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
