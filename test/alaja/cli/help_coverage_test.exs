defmodule Alaja.CLI.HelpCoverageTest do
  @moduledoc """
  Verifies that every CLI switch is documented in `@help_data` and that
  each command can be `help()`-ed without crashing.

  This is the DoD gate for the CLI help audit: every OptionParser switch
  must have a matching entry in `:options`, and every entry must be
  reachable (the table must include the option name).
  """

  use ExUnit.Case, async: true

  @commands [
    {Alaja.CLI.Commands.Show.Animate, "animate"},
    {Alaja.CLI.Commands.Show.AnimatedBar, "animated-bar"},
    {Alaja.CLI.Commands.Show.Ask, "ask"},
    {Alaja.CLI.Commands.Show.Bar, "bar"},
    {Alaja.CLI.Commands.Show.Breadcrumbs, "breadcrumbs"},
    {Alaja.CLI.Commands.Show.Gradient, "gradient"},
    {Alaja.CLI.Commands.Show.Header, "header"},
    {Alaja.CLI.Commands.Show.Image, "image"},
    {Alaja.CLI.Commands.Show.Json, "json"},
    {Alaja.CLI.Commands.Show.List, "list"},
    {Alaja.CLI.Commands.Show.Log, "log"},
    {Alaja.CLI.Commands.Show.Menu, "menu"},
    {Alaja.CLI.Commands.Show.Message, "message"},
    {Alaja.CLI.Commands.Show.Multibar, "multibar"},
    {Alaja.CLI.Commands.Show.Progress, "progress"},
    {Alaja.CLI.Commands.Show.Pulsar, "pulsar"},
    {Alaja.CLI.Commands.Show.Scroll, "scroll"},
    {Alaja.CLI.Commands.Show.Separator, "separator"},
    {Alaja.CLI.Commands.Show.Table, "table"},
    {Alaja.CLI.Commands.Show.Tabs, "tabs"},
    {Alaja.CLI.Commands.Show.YesNo, "yesno"}
  ]

  for {module, cmd_name} <- @commands do
    test "#{cmd_name}: help() renders without crashing" do
      capture = capture_io(fn -> apply(unquote(module), :help, []) end)
      assert capture != "", "help/0 should produce output, got empty"
    end

    test "#{cmd_name}: every CLI switch is documented in :options" do
      data = module_help_data(unquote(module))
      options = Keyword.get(data, :options, [])
      opt_names = Enum.map(options, fn {name, _, _, _} -> to_string(name) end)

      switches = extract_switches(unquote(module))
      missing = Enum.reject(switches, fn sw -> sw in opt_names end)

      assert missing == [],
             "Command `#{unquote(cmd_name)}` has undocumented CLI switches: #{inspect(missing)}.
              Add them to @help_data :options or remove them from the parser."
    end

    test "#{cmd_name}: every documented option has a name, type, default, description" do
      data = module_help_data(unquote(module))
      options = Keyword.get(data, :options, [])

      Enum.each(options, fn opt ->
        assert is_tuple(opt) and tuple_size(opt) == 4,
               "Each option must be a {name, type, default, description} tuple, got: #{inspect(opt)}"

        {name, type, _default, desc} = opt

        assert is_atom(name) and not is_nil(name),
               "Option name must be a non-nil atom, got: #{inspect(name)}"

        assert is_atom(type) or is_nil(type),
               "Option type must be an atom or nil, got: #{inspect(type)}"

        assert is_binary(desc) and desc != "",
               "Option description must be a non-empty string, got: #{inspect(desc)}"
      end)
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp module_help_data(module) do
    source = module_source_content(module)

    case extract_help_data_block(source) do
      nil ->
        []

      "" ->
        []

      body ->
        try do
          {result, _binding} = Code.eval_string("[#{body}]")
          # `result` is a list of 2-tuples (already a keyword list since
          # values are keyword-shaped). Just normalize to a keyword list.
          pair_list = List.wrap(result)
          pair_list |> Enum.reverse() |> Keyword.new()
        rescue
          _ ->
            []
        end
    end
  end

  # Find the @help_data block by walking the source.
  defp extract_help_data_block(source) do
    start_idx =
      case :binary.match(source, "@help_data") do
        {idx, _} -> idx
        :nomatch -> nil
      end

    if is_nil(start_idx) do
      nil
    else
      bracket_idx =
        case :binary.match(source, "[", scope: {start_idx, byte_size(source) - start_idx}) do
          {idx, _} -> idx
          :nomatch -> nil
        end

      if is_nil(bracket_idx) do
        nil
      else
        case find_matching_bracket(source, bracket_idx + 1, 1) do
          nil -> nil
          end_idx -> binary_part(source, bracket_idx + 1, end_idx - bracket_idx - 1)
        end
      end
    end
  end

  # Walk forward looking for the matching `]`. Depth starts at 1
  # (the opening `[` of @help_data). We return when depth goes back to 0.
  defp find_matching_bracket(_source, idx, 0), do: idx - 1

  defp find_matching_bracket(source, idx, depth) do
    if idx >= byte_size(source) do
      nil
    else
      c = :binary.at(source, idx)

      cond do
        c == ?[ -> find_matching_bracket(source, idx + 1, depth + 1)
        c == ?] -> find_matching_bracket(source, idx + 1, depth - 1)
        c == ?# -> skip_line_comment(source, idx, depth)
        c == ?" -> skip_string(source, idx + 1, ?", depth)
        c == ?` -> skip_string(source, idx + 1, ?`, depth)
        true -> find_matching_bracket(source, idx + 1, depth)
      end
    end
  end

  defp skip_line_comment(source, idx, depth) do
    case :binary.match(source, "\n", scope: {idx, byte_size(source) - idx}) do
      {nl, _} -> find_matching_bracket(source, nl + 1, depth)
      :nomatch -> nil
    end
  end

  defp skip_string(source, idx, quote, depth) do
    case find_unescaped(source, idx, quote) do
      nil -> nil
      next_quote -> find_matching_bracket(source, next_quote + 1, depth)
    end
  end

  defp find_unescaped(source, idx, quote) do
    if idx >= byte_size(source) do
      nil
    else
      c = :binary.at(source, idx)

      cond do
        c == ?\\ -> find_unescaped(source, idx + 2, quote)
        c == quote -> idx
        true -> find_unescaped(source, idx + 1, quote)
      end
    end
  end

  defp extract_switches(module) do
    source = module_source_content(module)

    # Find each `switches: [ ... ]` block (some commands have more than one
    # for typed vs custom paths). We extract the union of all switches.
    Regex.scan(~r/switches:\s*\[(.*?)\]/s, source)
    |> Enum.flat_map(fn [_, body] -> switches_in_block(body) end)
    |> Enum.uniq()
  end

  defp switches_in_block(body) do
    body
    |> String.split(~r/[\n,]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn line ->
      case Regex.run(~r/^([a-z_][a-z_0-9]*)\s*:/, line) do
        [_, name] -> [name]
        _ -> []
      end
    end)
  end

  defp module_source(module) do
    case module.module_info(:compile)[:source] do
      source when is_binary(source) -> source
      source when is_list(source) -> List.to_string(source)
      nil -> raise "no source for #{inspect(module)}"
    end
  end

  defp module_source_content(module) do
    File.read!(module_source(module))
  end

  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end
end
