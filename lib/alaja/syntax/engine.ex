defmodule Alaja.Syntax.Engine do
  @moduledoc """
  Generic single-pass character scanner driven by `Alaja.Syntax.Language`.

  Each scan position tries patterns in order; the first match wins.
  Multi-line constructs (block comments, multi-line strings) set a
  context that the next iteration resolves before trying new matches.
  """

  alias Alaja.Syntax.Language

  @word_re ~r/^([A-Za-z_]\w*)/

  @doc """
  Tokenizes source code into `{type, text}` tuples.
  """
  @spec tokenize(String.t(), Language.t()) :: [{atom(), String.t()}]
  def tokenize(content, lang) when is_binary(content) do
    do_scan(content, lang, 0, [], nil)
  end

  # ── Main loop ──────────────────────────────────────────────────────────

  defp do_scan(content, _lang, pos, acc, _ctx) when pos >= byte_size(content) do
    Enum.reverse(acc)
  end

  defp do_scan(content, lang, pos, acc, ctx) do
    {tokens, new_pos, new_ctx} = advance(content, lang, pos, ctx)
    do_scan(content, lang, new_pos, append_tokens(acc, tokens), new_ctx)
  end

  # ── Advance one token (or context) ─────────────────────────────────────

  defp advance(content, _lang, pos, {:block_comment, end_str}) do
    read_multiline(content, pos, end_str, :comment)
  end

  defp advance(content, _lang, pos, {:multiline_string, end_re, _escape}) do
    read_multiline(content, pos, end_re, :string)
  end

  defp advance(content, lang, pos, nil) do
    rest = slice_from(content, pos)
    match_first(content, lang, pos, rest)
  end

  # ── Match chain: first match wins ──────────────────────────────────────

  defp match_first(content, lang, pos, rest) do
    cond do
      (result = try_block_comment(content, lang, pos, rest)) != :none ->
        result

      (result = try_specials(content, lang, pos, rest)) != :none ->
        result

      (result = try_line_comment(content, lang, pos, rest)) != :none ->
        result

      (result = try_string(content, lang, pos, rest)) != :none ->
        result

      (result = try_number(content, lang, pos, rest)) != :none ->
        result

      (result = try_operator(content, lang, pos, rest)) != :none ->
        result

      (result = try_word(content, lang, pos, rest)) != :none ->
        result

      true ->
        char = String.first(rest)
        {[{:plain, char}], pos + byte_size(char), nil}
    end
  end

  # ── Block comment ─────────────────────────────────────────────────────

  defp try_block_comment(content, lang, pos, rest) do
    case lang.block_comment do
      %{start: start_s, end: end_s} ->
        if String.starts_with?(rest, start_s) do
          read_multiline(content, pos + byte_size(start_s), end_s, :comment)
        else
          :none
        end

      nil ->
        :none
    end
  end

  # ── Specials ──────────────────────────────────────────────────────────

  defp try_specials(content, lang, pos, rest) do
    sorted = Enum.sort_by(lang.specials, & &1.priority)
    find_special_match(content, pos, rest, sorted)
  end

  defp find_special_match(_content, _pos, _rest, []), do: :none

  defp find_special_match(content, pos, rest, [s | tail]) do
    case match_start(rest, s.pattern) do
      {:ok, match, _match_len} ->
        cond do
          s.consume -> {[{:plain, match}], pos + byte_size(match), nil}
          s.multiline -> read_multiline(content, pos + byte_size(match), s.pattern, s.type)
          true -> {[{s.type, match}], pos + byte_size(match), nil}
        end

      :none ->
        find_special_match(content, pos, rest, tail)
    end
  end

  # ── Line comment ──────────────────────────────────────────────────────

  defp try_line_comment(content, lang, pos, rest) do
    case lang.line_comment do
      nil ->
        :none

      marker ->
        if String.starts_with?(rest, marker) do
          line = line_until(content, pos)
          {[{:comment, line}], pos + byte_size(line), nil}
        else
          :none
        end
    end
  end

  # ── String ────────────────────────────────────────────────────────────

  defp try_string(content, lang, pos, rest) do
    try_string_chain(content, pos, rest, lang.strings)
  end

  defp try_string_chain(_content, _pos, _rest, []), do: :none

  defp try_string_chain(content, pos, rest, [s | tail]) do
    case match_start(rest, s.delim) do
      {:ok, match, _match_len} ->
        inner_start = pos + byte_size(match)
        end_pattern = s.end
        multiline? = Map.get(s, :multiline, false)

        if multiline? do
          read_multiline(content, inner_start, end_pattern, :string)
        else
          read_single_line_string(content, inner_start, end_pattern)
        end

      :none ->
        try_string_chain(content, pos, rest, tail)
    end
  end

  defp read_single_line_string(content, pos, end_re) do
    line = line_until(content, pos)

    case Regex.run(end_re, line, return: :index) do
      [{match_start, match_len}] ->
        end_pos = pos + match_start + match_len
        full = slice_from_to(content, pos - 1, end_pos)
        {[{:string, full}], end_pos, nil}

      nil ->
        {[{:string, line}], pos + byte_size(line), nil}
    end
  end

  # ── Number ────────────────────────────────────────────────────────────

  defp try_number(_content, lang, pos, rest) do
    case lang.number do
      nil ->
        first = String.first(rest)

        if first >= "0" and first <= "9" do
          digits = take_while(rest, &(&1 >= "0" and &1 <= "9"))
          {[{:number, digits}], pos + byte_size(digits), nil}
        else
          :none
        end

      re ->
        case match_start(rest, re) do
          {:ok, match, _len} ->
            {[{:number, match}], pos + byte_size(match), nil}

          :none ->
            :none
        end
    end
  end

  # ── Operator ──────────────────────────────────────────────────────────

  defp try_operator(content, lang, pos, rest) do
    if MapSet.size(lang.operators) == 0 do
      :none
    else
      sorted = Enum.sort_by(lang.operators, &byte_size/1, :desc)

      case Enum.find(sorted, &String.starts_with?(rest, &1)) do
        nil -> :none
        op -> process_operator(content, op, pos)
      end
    end
  end

  defp process_operator(content, op, pos) do
    if String.match?(op, ~r/^[A-Za-z]+$/) do
      after_op = slice_from(content, pos + byte_size(op))
      before_char = if pos > 0, do: slice_from_to(content, pos - 1, pos), else: ""

      if word_boundary?(pos, before_char, after_op) do
        {[{:operator, op}], pos + byte_size(op), nil}
      else
        :none
      end
    else
      {[{:operator, op}], pos + byte_size(op), nil}
    end
  end

  defp word_boundary?(0, _before, _after), do: true

  defp word_boundary?(_pos, before_char, after_op) do
    not String.match?(before_char, ~r/[A-Za-z0-9_]/) and
      (after_op == "" or not String.match?(String.first(after_op), ~r/[A-Za-z0-9_]/))
  end

  # ── Word ──────────────────────────────────────────────────────────────

  defp try_word(content, lang, pos, rest) do
    case Regex.run(@word_re, rest) do
      [_, word] when is_binary(word) and word != "" ->
        try_qualified_name(content, lang, pos, word)

      _ ->
        :none
    end
  end

  defp try_qualified_name(content, lang, pos, word) do
    sep = lang.module_separator
    after_word = pos + byte_size(word)
    after_slice = slice_from(content, after_word)

    if sep != "" and String.starts_with?(after_slice, sep) and
         byte_size(after_slice) > byte_size(sep) do
      after_sep = slice_from(content, after_word + byte_size(sep))

      case Regex.run(@word_re, after_sep) do
        [_, next] when is_binary(next) and next != "" ->
          qualified = word <> sep <> next
          {[{:module, qualified}], after_word + byte_size(sep) + byte_size(next), nil}

        _ ->
          classify_and_emit(word, lang, pos)
      end
    else
      classify_and_emit(word, lang, pos)
    end
  end

  defp classify_and_emit(word, lang, pos) do
    type = classify(word, lang)
    {[{type, word}], pos + byte_size(word), nil}
  end

  defp classify(word, lang) do
    cond do
      MapSet.member?(lang.keywords, word) -> :keyword
      MapSet.member?(lang.types, word) -> :type
      true -> :plain
    end
  end

  # ── Multi-line reader ─────────────────────────────────────────────────

  defp read_multiline(content, pos, _end_pattern, _type) when pos >= byte_size(content) do
    {[], byte_size(content), nil}
  end

  defp read_multiline(content, pos, end_pattern, type) do
    end_regex = to_regex(end_pattern)

    case Regex.run(end_regex, content, return: :index, offset: pos) do
      [{match_start, match_len}] ->
        text = slice_from_to(content, pos, match_start + match_len)
        {[{type, text}], match_start + match_len, nil}

      nil ->
        {[], pos, {type_to_context(type), end_pattern}}
    end
  end

  defp type_to_context(:comment), do: :block_comment
  defp type_to_context(:string), do: :multiline_string
  defp type_to_context(_), do: :multiline_text

  # ── Matching helper (ensures pattern matches at start of rest) ──────────

  defp match_start(rest, pattern) do
    case Regex.run(pattern, rest, return: :index) do
      [{0, len}] when len > 0 ->
        {:ok, binary_part(rest, 0, len), len}

      _ ->
        :none
    end
  end

  # ── Slice helpers (avoid Kernel.binary_slice conflict) ──────────────────

  defp slice_from(content, offset) do
    size = byte_size(content) - offset
    if size > 0, do: :binary.part(content, offset, size), else: ""
  end

  defp slice_from_to(content, from, to) do
    len = to - from
    :binary.part(content, from, min(len, byte_size(content) - from))
  end

  defp line_until(content, pos) do
    case :binary.match(content, "\n", scope: {pos, byte_size(content) - pos}) do
      {nl, _} -> slice_from_to(content, pos, nl)
      :nomatch -> slice_from(content, pos)
    end
  end

  defp take_while(str, pred) when is_binary(str) do
    take_while(str, pred, 0)
  end

  defp take_while(str, _pred, idx) when idx >= byte_size(str), do: str

  defp take_while(str, pred, idx) do
    c = slice_from_to(str, idx, idx + 1)

    if c != "" and pred.(c) do
      take_while(str, pred, idx + 1)
    else
      slice_from_to(str, 0, idx)
    end
  end

  defp to_regex(pattern) when is_struct(pattern, Regex), do: pattern

  defp to_regex(pattern) when is_binary(pattern) do
    case Regex.compile(Regex.escape(pattern)) do
      {:ok, re} -> re
      {:error, reason} -> raise ArgumentError, "invalid regex pattern: #{reason}"
    end
  end

  defp to_regex({:regex, source}) do
    case Regex.compile(source) do
      {:ok, re} -> re
      {:error, reason} -> raise ArgumentError, "invalid regex source: #{reason}"
    end
  end

  defp append_tokens(acc, []), do: acc
  defp append_tokens(acc, tokens), do: Enum.reduce(tokens, acc, &[&1 | &2])
end
