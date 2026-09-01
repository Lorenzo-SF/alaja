defmodule Alaja.Components.Json do
  @moduledoc """
  Static JSON pretty-printer with syntax highlighting for terminal output.

  Renders JSON with ANSI colors differentiated by value type.

  ## Usage

      iex> Alaja.Components.Json.print(%{name: "Alaja", version: "1.0.0"})

  ## Cell engine

  As of v0.3.0, `render/2` returns an `Alaja.Buffer.t/0`. Each line
  becomes one row; multi-line JSON (objects, arrays) become multi-row
  buffers. Each character is placed with the colour matching its
  JSON token type.

  ## Theme integration (v2.0.0+)

  When no `:key_color` / `:string_color` / etc. are supplied, the
  defaults are `theme:quaternary`, `theme:success`, `theme:info`,
  `theme:ternary`, `theme:sad`, `theme:no_color` — they resolve
  through `Alaja.CLI.Color.parse/1` so the active theme
  picks them up. Pass an RGB tuple, hex string, or atom to override.
  """

  alias Alaja.{Buffer, Cell}

  @key_color "theme:quaternary"
  @string_color "theme:success"
  @number_color "theme:info"
  @boolean_color "theme:ternary"
  @null_color "theme:sad"
  @punctuation_color "theme:no_color"

  @doc """
  Prints JSON to stdout with syntax highlighting.
  """
  @spec print(term(), keyword()) :: :ok
  def print(data, opts \\ []) do
    data
    |> render(opts)
    |> Buffer.to_iodata()
    |> IO.write()

    IO.puts("")
  end

  @doc """
  Renders JSON to an `Alaja.Buffer.t/0`.
  """
  @spec render(term(), keyword()) :: Buffer.t()
  def render(data, opts \\ []) do
    indent = Keyword.get(opts, :indent, 2)
    colors = build_colors(opts)

    sorted = sort_keys(data)

    text =
      case Jason.encode(sorted, pretty: [indent: String.duplicate(" ", indent)]) do
        {:ok, encoded} -> encoded
        {:error, _} -> "{}"
      end

    lines = String.split(text, "\n")
    total_h = length(lines)
    total_w = lines |> Enum.map(&String.length/1) |> Enum.max(fn -> 0 end)

    buffer = Buffer.new(total_w, total_h)

    lines
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {line, y}, buf -> write_json_line(buf, 0, y, line, colors) end)
  end

  defp build_colors(opts) do
    %{
      key: resolve_color(Keyword.get(opts, :key_color, @key_color)),
      string: resolve_color(Keyword.get(opts, :string_color, @string_color)),
      number: resolve_color(Keyword.get(opts, :number_color, @number_color)),
      boolean: resolve_color(Keyword.get(opts, :boolean_color, @boolean_color)),
      null: resolve_color(Keyword.get(opts, :null_color, @null_color)),
      punctuation: resolve_color(Keyword.get(opts, :punctuation_color, @punctuation_color))
    }
  end

  # Resolve a color spec to an RGB tuple. Accepts:
  #   * an RGB tuple `{r, g, b}` — returned as-is
  #   * a string ("theme:primary", "#FF0000", "red", ...) — parsed via Pote
  #   * `nil` — returned as nil (no colour)
  defp resolve_color({r, g, b} = rgb)
       when is_integer(r) and is_integer(g) and is_integer(b),
       do: rgb

  defp resolve_color(s) when is_binary(s) do
    case Alaja.CLI.Color.parse(s) do
      {:ok, rgb} -> rgb
      _ -> nil
    end
  end

  defp resolve_color(nil), do: nil
  defp resolve_color(_), do: nil

  # Tokenizer-based writer. Walks the line char by char, identifying
  # tokens and writing coloured cells. Strings are tracked across the
  # whole line so that spaces inside strings keep the string colour.
  defp write_json_line(buffer, x, y, line, colors) do
    {_, _, buffer} =
      line
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.reduce({:normal, x, buffer}, fn {char, idx}, {state, cx, buf} ->
        target_x = cx + idx

        if target_x >= buf.width do
          {state, cx, buf}
        else
          {new_state, color} = next_state(state, char, line, idx, colors)
          cell = Cell.new(char, color)
          {new_state, cx, Buffer.update_cell(buf, target_x, y, cell)}
        end
      end)

    buffer
  end

  # State machine. States:
  #   :normal  - looking for next token
  #   :string  - inside a "..." string
  #   {:keyword, color, remaining} - inside a true/false/null keyword,
  #                                    remaining chars to colour
  defp next_state({:keyword, color, remaining}, _char, _line, _idx, _colors) do
    if remaining > 1, do: {{:keyword, color, remaining - 1}, color}, else: {:normal, color}
  end

  defp next_state(:string, char, _line, _idx, colors) do
    if char == ~s(") do
      {:normal, colors.string}
    else
      {:string, colors.string}
    end
  end

  defp next_state(:normal, char, line, idx, colors) do
    cond do
      char == ~s(") ->
        {:string, colors.string}

      char in ~w(0 1 2 3 4 5 6 7 8 9 . - + e E) ->
        {:normal, colors.number}

      char in ~w({ } [ ] , :) ->
        {:normal, colors.punctuation}

      char in [" ", "\t"] ->
        {:normal, nil}

      true ->
        match_keyword_state(line, idx, colors)
    end
  end

  defp match_keyword_state(line, idx, colors) do
    cond do
      match_keyword(line, idx, "true") -> {{:keyword, colors.boolean, 4}, colors.boolean}
      match_keyword(line, idx, "false") -> {{:keyword, colors.boolean, 5}, colors.boolean}
      match_keyword(line, idx, "null") -> {{:keyword, colors.null, 4}, colors.null}
      true -> {:normal, nil}
    end
  end

  defp sort_keys(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> {k, sort_keys(v)} end)
    |> Jason.OrderedObject.new()
  end

  defp sort_keys(list) when is_list(list), do: Enum.map(list, &sort_keys/1)
  defp sort_keys(value), do: value

  defp match_keyword(line, idx, word) do
    len = String.length(word)

    cond do
      String.length(line) < idx + len ->
        false

      String.slice(line, idx, len) != word ->
        false

      true ->
        next_char_pos = idx + len

        if next_char_pos >= String.length(line) do
          true
        else
          next_char = String.at(line, next_char_pos) || ""

          # Whitespace OR structural delimiter ends a keyword
          next_char == " " or
            next_char == "\t" or
            next_char == "\n" or
            next_char in [",", "]", "}"]
        end
    end
  end
end
