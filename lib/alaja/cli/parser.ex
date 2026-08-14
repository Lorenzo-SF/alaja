defmodule Alaja.CLI.Parser do
  @moduledoc """
  Shared parsing utilities for CLI commands.

  Handles repeated flags, quoted values, environment variables,
  color parsing, and other common patterns.
  """

  # ---------------------------------------------------------------------------
  # Repeated flag collection
  # ---------------------------------------------------------------------------

  @doc """
  Collects all values for a repeated `--flag` from raw args.

  Supports both `--flag value` and `--flag=value` forms.
  """
  @spec collect_repeated([String.t()], String.t()) :: [String.t()]
  def collect_repeated(args, flag) do
    equals =
      args
      |> Enum.filter(&String.starts_with?(&1, flag <> "="))
      |> Enum.map(&String.replace_prefix(&1, flag <> "=", ""))
      |> Enum.map(&strip_quotes/1)

    spaces = collect_flag_values(args, flag)
    equals ++ spaces
  end

  defp collect_flag_values(args, flag), do: collect_values(args, flag, 0, [])

  defp collect_values(args, flag, idx, acc) do
    total = length(args)

    cond do
      idx >= total ->
        Enum.reverse(acc)

      Enum.at(args, idx) == flag ->
        {value, next_idx} = extract_next_value(args, idx + 1, total)

        if value,
          do: collect_values(args, flag, next_idx, [value | acc]),
          else: collect_values(args, flag, idx + 1, acc)

      true ->
        collect_values(args, flag, idx + 1, acc)
    end
  end

  defp extract_next_value(args, start_idx, total) do
    if start_idx >= total do
      {nil, start_idx}
    else
      current = Enum.at(args, start_idx)
      quote_type = detect_quote_type(current)

      if quote_type do
        extract_quoted_value(args, start_idx, quote_type, total)
      else
        collect_until_flag(args, start_idx, total, [])
      end
    end
  end

  defp collect_until_flag(args, idx, total, acc) do
    if idx >= total do
      {Enum.join(Enum.reverse(acc), " "), idx}
    else
      current = Enum.at(args, idx)

      cond do
        String.starts_with?(current, "--") ->
          {Enum.join(Enum.reverse(acc), " "), idx}

        String.starts_with?(current, "-") and byte_size(current) > 1 ->
          {Enum.join(Enum.reverse(acc), " "), idx}

        true ->
          collect_until_flag(args, idx + 1, total, [current | acc])
      end
    end
  end

  defp detect_quote_type(arg) do
    trimmed = String.trim(arg)

    cond do
      String.starts_with?(trimmed, "\"") -> "\""
      String.starts_with?(trimmed, "'") -> "'"
      true -> nil
    end
  end

  defp extract_quoted_value(args, start_idx, quote_char, total) do
    first = String.trim(Enum.at(args, start_idx))

    initial =
      if String.starts_with?(first, quote_char),
        do: String.slice(first, 1..-1//1),
        else: first

    if String.ends_with?(first, quote_char) do
      cleaned = String.slice(initial, 0..(-String.length(quote_char) - 1))
      {cleaned, start_idx + 1}
    else
      collect_until_close(args, start_idx + 1, quote_char, total, initial)
    end
  end

  defp collect_until_close(args, idx, quote_char, total, acc) do
    if idx >= total do
      {acc, idx}
    else
      current = String.trim(Enum.at(args, idx))

      if String.ends_with?(current, quote_char) do
        middle = String.slice(current, 0..(-String.length(quote_char) - 1))
        {Enum.join([acc, middle], " "), idx + 1}
      else
        collect_until_close(args, idx + 1, quote_char, total, Enum.join([acc, current], " "))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Color parsing
  # ---------------------------------------------------------------------------

  @doc """
  Parses a color string using the standard `<formato>:<codigo>` format.
  Returns `{:ok, {r,g,b}}` or `{:error, reason}`.
  """
  @spec parse_color(String.t() | nil) :: {:ok, {byte(), byte(), byte()}} | {:error, term()} | nil
  def parse_color(nil), do: nil

  def parse_color(str) when is_binary(str) do
    str = String.trim(str) |> String.trim("\"") |> String.trim("'")
    Alaja.CLI.Color.parse(str)
  end

  @doc """
  Parses a color and returns the RGB tuple, or prints error to stderr and returns nil.
  """
  @spec parse_color_opt(String.t() | nil) :: {byte(), byte(), byte()} | nil
  def parse_color_opt(nil), do: nil

  def parse_color_opt(str) when is_binary(str) do
    case parse_color(str) do
      {:ok, rgb} ->
        rgb

      {:error, msg} ->
        IO.puts(:stderr, msg)
        nil

      nil ->
        nil
    end
  end

  @doc """
  Parses a `|`-separated list of colors.
  Returns `{:ok, [{r,g,b}, ...]}` or `{:error, message}`.
  """
  @spec parse_color_list(String.t() | nil) :: {:ok, [tuple()]} | {:error, String.t()} | nil
  def parse_color_list(nil), do: nil

  def parse_color_list(str) when is_binary(str) do
    Alaja.CLI.Color.parse_list(str)
  end

  # ---------------------------------------------------------------------------
  # Environment variable parsing
  # ---------------------------------------------------------------------------

  @doc """
  Parses a `KEY=VALUE` string into a tuple.
  """
  @spec parse_env_pair(String.t()) :: {atom(), String.t()} | nil
  def parse_env_pair(pair) do
    case String.split(pair, "=", parts: 2) do
      [k, v] ->
        case Alaja.Helpers.safe_string_to_atom(k) do
          {:ok, atom} -> {atom, v}
          {:error, _} -> nil
        end

      _ ->
        nil
    end
  end

  # ---------------------------------------------------------------------------
  # Alignment
  # ---------------------------------------------------------------------------

  @doc """
  Parses an alignment string into an atom.
  """
  @spec parse_align(String.t() | atom() | nil) :: :left | :center | :right
  def parse_align(nil), do: :left
  def parse_align(a) when is_atom(a), do: a
  def parse_align("left"), do: :left
  def parse_align("center"), do: :center
  def parse_align("right"), do: :right
  def parse_align(_), do: :left

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp strip_quotes(value) do
    value |> String.trim() |> String.trim("\"") |> String.trim("'")
  end
end
