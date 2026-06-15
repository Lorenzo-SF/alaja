defmodule Alaja.Components.Json do
  @moduledoc """
  Static JSON pretty-printer with syntax highlighting for terminal output.

  Renders JSON with ANSI colors differentiated by value type.

  ## Usage

      iex> Alaja.Components.Json.print(%{name: "Alaja", version: "1.0.0"})
      # {
      #   "name": "Alaja",
      #   "version": "1.0.0"
      # }
  """

  @key_color {86, 182, 194}
  @string_color {152, 195, 121}
  @number_color {209, 154, 102}
  @boolean_color {198, 120, 221}
  @null_color {128, 128, 128}
  @punctuation_color {180, 180, 180}

  @doc """
  Prints JSON to stdout with syntax highlighting.

  ## Options

  - `:indent` - Indentation in spaces (default: 2)
  - `:key_color` - RGB for object keys
  - `:string_color` - RGB for string values
  - `:number_color` - RGB for numbers
  - `:boolean_color` - RGB for booleans
  - `:null_color` - RGB for null values
  """
  @spec print(term(), keyword()) :: :ok
  def print(data, opts \\ []) do
    data |> render(opts) |> IO.write()
    IO.puts("")
  end

  @doc """
  Renders JSON to iodata without printing.
  """
  @spec render(term(), keyword()) :: iodata()
  def render(data, opts \\ []) do
    indent = Keyword.get(opts, :indent, 2)
    colors = build_colors(opts)

    render_value(data, 0, indent, colors)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_colors(opts) do
    %{
      key: Keyword.get(opts, :key_color, @key_color),
      string: Keyword.get(opts, :string_color, @string_color),
      number: Keyword.get(opts, :number_color, @number_color),
      boolean: Keyword.get(opts, :boolean_color, @boolean_color),
      null: Keyword.get(opts, :null_color, @null_color),
      punctuation: Keyword.get(opts, :punctuation_color, @punctuation_color)
    }
  end

  defp color({r, g, b}), do: Pote.Orchestrator.to_ansi({r, g, b})
  defp reset, do: Alaja.ANSI.reset_attributes()

  defp indent_str(level, size), do: String.duplicate(" ", level * size)

  defp render_value(nil, _level, _indent, colors) do
    [color(colors.null), "null", reset()]
  end

  defp render_value(true, _level, _indent, colors) do
    [color(colors.boolean), "true", reset()]
  end

  defp render_value(false, _level, _indent, colors) do
    [color(colors.boolean), "false", reset()]
  end

  defp render_value(value, _level, _indent, colors) when is_integer(value) or is_float(value) do
    [color(colors.number), to_string(value), reset()]
  end

  defp render_value(value, _level, _indent, colors) when is_binary(value) do
    escaped = String.replace(value, "\"", "\\\"")
    [color(colors.string), "\"", escaped, "\"", reset()]
  end

  defp render_value(value, _level, _indent, colors) when is_atom(value) do
    escaped = to_string(value)
    [color(colors.string), "\"", escaped, "\"", reset()]
  end

  defp render_value([], _level, _indent, colors) do
    [color(colors.punctuation), "[]", reset()]
  end

  defp render_value(list, level, indent, colors) when is_list(list) do
    inner_indent = indent_str(level + 1, indent)
    outer_indent = indent_str(level, indent)

    items =
      list
      |> Enum.map(fn item ->
        [inner_indent, render_value(item, level + 1, indent, colors)]
      end)
      |> Enum.intersperse([color(colors.punctuation), ",", reset(), "\n"])

    [
      color(colors.punctuation),
      "[\n",
      reset(),
      items,
      "\n",
      outer_indent,
      color(colors.punctuation),
      "]",
      reset()
    ]
  end

  defp render_value(map, level, indent, colors) when is_map(map) do
    if map_size(map) == 0 do
      [color(colors.punctuation), "{}", reset()]
    else
      inner_indent = indent_str(level + 1, indent)
      outer_indent = indent_str(level, indent)

      pairs =
        map
        |> Enum.map(fn {key, value} ->
          key_str = to_string(key)

          [
            inner_indent,
            color(colors.key),
            "\"",
            key_str,
            "\"",
            reset(),
            color(colors.punctuation),
            ": ",
            reset(),
            render_value(value, level + 1, indent, colors)
          ]
        end)
        |> Enum.intersperse([color(colors.punctuation), ",", reset(), "\n"])

      [
        color(colors.punctuation),
        "{\n",
        reset(),
        pairs,
        "\n",
        outer_indent,
        color(colors.punctuation),
        "}",
        reset()
      ]
    end
  end

  defp render_value(value, _level, _indent, _colors) do
    inspect(value)
  end
end
