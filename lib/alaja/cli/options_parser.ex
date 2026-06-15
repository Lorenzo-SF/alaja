defmodule Alaja.CLI.OptionsParser do
  @moduledoc """
  Standardized option parsing for CLI commands.

  Provides a consistent way to parse command-line options using a schema-based approach.
  """

  @type switch_type :: :string | :integer | :float | :boolean | :atom
  @type switch :: {atom(), switch_type()}
  @type alias_list :: [{atom(), atom()}]

  @type schema :: %{
          required(:switches) => [switch()],
          optional(:aliases) => alias_list(),
          optional(:defaults) => keyword()
        }

  @type parse_result :: {keyword(), [String.t()], [String.t()]}

  @spec parse([String.t()], schema()) :: parse_result()
  def parse(args, schema) when is_list(args) and is_map(schema) do
    switches = Keyword.new(schema[:switches] || [])
    aliases = schema[:aliases] || []
    defaults = schema[:defaults] || []

    {parsed, rest, errors} = parse_options(args, switches, aliases)

    merged_opts = Keyword.merge(defaults, parsed)
    {merged_opts, rest, errors}
  end

  @spec parse_value(String.t(), switch_type()) :: any()
  def parse_value(value, type) do
    case type do
      :string -> value
      :integer -> parse_integer(value)
      :float -> parse_float(value)
      :boolean -> parse_boolean(value)
      :atom -> parse_atom(value)
      _ -> value
    end
  end

  defp parse_options(args, switches, aliases) do
    parse_loop(args, switches, aliases, [], [], [])
  end

  defp parse_loop([], _switches, _aliases, parsed, rest, errors) do
    {Enum.reverse(parsed), Enum.reverse(rest), Enum.reverse(errors)}
  end

  defp parse_loop(["--" <> opt | rest], switches, aliases, parsed, rest_acc, errors) do
    case parse_long_option(opt, rest, switches, aliases) do
      {:ok, {key, value}, new_rest} ->
        parse_loop(new_rest, switches, aliases, [{key, value} | parsed], rest_acc, errors)

      {:error, reason} ->
        parse_loop(rest, switches, aliases, parsed, rest_acc, [reason | errors])
    end
  end

  defp parse_loop(["-" <> opt | rest], switches, aliases, parsed, rest_acc, errors) do
    case parse_short_option(opt, rest, switches, aliases) do
      {:ok, {key, value}, new_rest} ->
        parse_loop(new_rest, switches, aliases, [{key, value} | parsed], rest_acc, errors)

      {:error, reason} ->
        parse_loop(rest, switches, aliases, parsed, rest_acc, [reason | errors])
    end
  end

  defp parse_loop([arg | rest], switches, aliases, parsed, rest_acc, errors) do
    parse_loop(rest, switches, aliases, parsed, [arg | rest_acc], errors)
  end

  defp parse_long_option(opt, rest, switches, aliases) do
    case String.split(opt, "=", parts: 2) do
      [key_str] ->
        key = String.to_existing_atom(key_str)
        real_key = get_alias(key, aliases, key)
        type = get_switch_type(real_key, switches)

        cond do
          type == :boolean ->
            {:ok, {real_key, true}, rest}

          rest == [] ->
            {:error, "--#{key_str} requires a value"}

          true ->
            value = hd(rest)
            {:ok, {real_key, parse_value(value, type)}, tl(rest)}
        end

      [key_str, value] ->
        key = String.to_existing_atom(key_str)
        real_key = get_alias(key, aliases, key)
        type = get_switch_type(real_key, switches)
        {:ok, {real_key, parse_value(value, type)}, rest}
    end
  rescue
    ArgumentError -> {:error, "--#{opt} is not a valid option"}
  end

  defp parse_short_option(opt, rest, switches, aliases) do
    key_str = String.split(opt, "=", parts: 2) |> hd()
    key = String.to_existing_atom(key_str)
    real_key = get_alias(key, aliases, key)
    type = get_switch_type(real_key, switches)

    cond do
      type == :boolean ->
        {:ok, {real_key, true}, rest}

      String.contains?(opt, "=") ->
        [_, value] = String.split(opt, "=", parts: 2)
        {:ok, {real_key, parse_value(value, type)}, rest}

      rest == [] ->
        {:error, "-#{key_str} requires a value"}

      true ->
        value = hd(rest)
        {:ok, {real_key, parse_value(value, type)}, tl(rest)}
    end
  rescue
    ArgumentError -> {:error, "-#{opt} is not a valid option"}
  end

  defp get_alias(key, aliases, default) do
    case Keyword.get(aliases, key) do
      nil -> default
      alias_key -> alias_key
    end
  end

  defp get_switch_type(key, switches) do
    case Keyword.get(switches, key) do
      nil -> :string
      type -> type
    end
  end

  defp parse_integer(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error -> value
    end
  end

  defp parse_float(value) do
    case Float.parse(value) do
      {n, _} -> n
      :error -> value
    end
  end

  defp parse_boolean(value) do
    value in ["true", "1", "yes", "on"]
  end

  defp parse_atom(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> value
  end
end
