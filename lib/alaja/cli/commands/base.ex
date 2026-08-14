defmodule Alaja.CLI.Commands.Base do
  @moduledoc """
  Provides generic helpers used across `Alaja.CLI.Commands.Show.*` modules.
  Functions are largely common parsing utilities for colors, alignment, and effects,
  as well as terminal width and alignment helpers.
  """

  alias Alaja.CLI.Parser
  alias Alaja.Helpers

  @doc "Parse a color string using :Parser."
  def parse_color(nil), do: nil
  def parse_color(s) when is_binary(s), do: Parser.parse_color_opt(s)
  def parse_color(_), do: nil

  @doc "Parse a semicolon separated list of colors."
  def parse_color_list(nil), do: nil

  def parse_color_list(s) when is_binary(s) do
    case Parser.parse_color_list(s) do
      {:ok, colors} ->
        colors

      {:error, msg} ->
        IO.puts(:stderr, msg)
        nil
    end
  end

  def parse_color_list(_), do: nil

  @doc "Parse alignment from a binary or atom. Returns an atom `:left`, `:center`, or `:right`. Defaults to `:left`."
  def parse_align(nil), do: nil
  def parse_align(a) when is_atom(a), do: a
  def parse_align(s) when is_binary(s), do: Helpers.safe_string_to_atom(s)
  def parse_align(_), do: nil

  @doc "Parse a comma separated list of align atoms. Returns a list of atoms or `nil` if input is nil."
  def parse_align_list(nil), do: nil

  def parse_align_list(s) when is_binary(s) do
    s
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&Helpers.safe_string_to_atom/1)
    |> Enum.reject(&is_nil/1)
  end

  def parse_align_list(_), do: nil

  @doc "Parse a comma separated list of effects atoms."
  def parse_effects(nil), do: nil

  def parse_effects(s) when is_binary(s) do
    s
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&Helpers.safe_string_to_atom/1)
    |> Enum.reject(&is_nil/1)
  end

  def parse_effects(_), do: nil

  @doc "Parse a comma separated list of effects atoms for per-object use."
  def parse_effects_list(nil), do: nil
  def parse_effects_list(s) when is_binary(s), do: parse_effects(s)
  def parse_effects_list(_), do: nil

  @doc "Render terminal width, defaulting to 80. Because `:io.columns/0` may fail in non-interactive contexts."
  def term_width do
    case :io.columns() do
      {:ok, w} -> w
      _ -> 80
    end
  end

  @doc "Apply alignment to a string. Works for `:left`, `:center`, and `:right`. For `:left` and other values it returns the string unchanged."
  def apply_align(line, :left), do: line

  def apply_align(line, align) when align in [:center, :right] do
    visible_len = line |> String.replace(~r/\x1b\[[0-9;]*m/, "") |> String.length()

    padding =
      case align do
        :center -> max(0, div(term_width() - visible_len, 2))
        :right -> max(0, term_width() - visible_len)
      end

    String.duplicate(" ", padding) <> line
  end

  def apply_align(line, _), do: line

  @doc "Parse border style to a color atom. Wraps `Helpers.safe_string_to_atom`."
  def parse_border_opt(s) when is_binary(s) do
    case Helpers.safe_string_to_atom(s) do
      {:ok, atom} -> atom
      {:error, _} -> :normal
    end
  end

  def parse_border_opt(_), do: :normal
end
