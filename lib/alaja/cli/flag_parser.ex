defmodule Alaja.CLI.FlagParser do
  @moduledoc """
  Flag parsing for `Alaja.CLI.Definition`.

  Splits out the recursive flag-matching logic from `Alaja.CLI.Definition`
  so the DSL macro module remains focused on command/argument declaration.

  Not part of the public API — used only by `Alaja.CLI.Definition`.
  """

  @doc """
  Parses argv tokens against a list of flag definitions.

  Returns `{:ok, parsed_flags, remaining_args}` on success or
  `{:error, message}` on parse error.

  Flags are matched greedily by prefix; the first flag whose name is
  a prefix of the current arg wins. Booleans are matched without a value
  (presence = `true`), while typed flags consume the next arg as their
  value (unless the current arg uses `=value` syntax).
  """
  @spec parse([map()], [String.t()]) :: {:ok, [{atom(), term()}]} | {:error, String.t()}
  def parse(flags, args) do
    do_parse(flags, args, [])
  end

  @spec match_flag([map()], [String.t()]) :: map() | nil
  def match_flag([], _args), do: nil
  def match_flag([flag | rest], [arg | _]) do
    if flag_matches?(flag, arg), do: flag, else: match_flag(rest, [arg])
  end
  def match_flag(_flags, []), do: nil

  defp flag_matches?(%{name: name}, arg) do
    case arg do
      "--" <> rest -> String.starts_with?(rest, to_string(name))
      "-" <> _ -> false
      _ -> false
    end
  end
  defp flag_matches?(_flag, _arg), do: false

  # ─── Internal: recursive flag parsing ─────────────────────────────

  defp do_parse(flags, args, acc) do
    matched = match_flag(flags, args)
    parse_matched(matched, flags, args, acc)
  end

  defp parse_matched(nil, _flags, args, acc), do: {:ok, acc, args}

  defp parse_matched(%{type: :boolean, repeatable: true} = flag, flags, [arg | rest], acc) do
    {value, next} = boolean_value(arg, rest)
    do_parse(flags -- [flag], next, [{flag.name, value} | acc])
  end

  defp parse_matched(%{type: :boolean} = flag, flags, [arg | rest], acc) do
    {value, next} = boolean_value(arg, rest)
    do_parse(flags -- [flag], next, [{flag.name, value} | acc])
  end

  defp parse_matched(%{type: :boolean} = flag, _flags, [], acc) do
    do_parse([flag], [], [{flag.name, true} | acc])
  end

  defp parse_matched(%{repeatable: true} = flag, flags, [arg | rest], acc) do
    {value, remaining} = parse_value(arg, rest)
    parsed = cast(flag.type, value, flag.default)
    do_parse(flags, remaining, [{flag.name, parsed} | acc])
  end

  defp parse_matched(%{} = flag, flags, [arg | rest], acc) do
    {value, remaining} = parse_value(arg, rest)
    parsed = cast(flag.type, value, flag.default)
    do_parse(flags -- [flag], remaining, [{flag.name, parsed} | acc])
  end

  defp parse_matched(%{} = _flag, _flags, [], acc) do
    {:ok, acc, []}
  end

  # ─── Helpers ────────────────────────────────────────────────────────

  defp boolean_value(arg, rest) do
    if arg =~ "=true" or arg =~ "=false" do
      {String.contains?(arg, "=true"), rest}
    else
      {true, rest}
    end
  end

  defp parse_value(arg, rest) do
    case String.split(arg, "=", parts: 2) do
      [_flag, value] -> {value, rest}
      [_flag] -> {hd_or_default(rest), tl(rest)}
    end
  end

  defp hd_or_default([h | _]), do: h
  defp hd_or_default([]), do: ""

  defp cast(:string, value, _default), do: value
  defp cast(:integer, value, default) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> default
    end
  end
  defp cast(:float, value, default) do
    case Float.parse(value) do
      {f, ""} -> f
      _ -> default
    end
  end
  defp cast(:boolean, value, default) do
    case value do
      "true" -> true
      "false" -> false
      _ -> default
    end
  end
  defp cast(:atom, value, default) do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> default
    end
  end
  defp cast(_, value, _default), do: value
end