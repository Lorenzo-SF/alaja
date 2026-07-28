defmodule Alaja.CLI.Commands.Show.Pulsar.Data do
  @moduledoc false

  alias Pote.Orchestrator

  @default_pulse_chars ["░", "▒", "▓", "█"]

  @doc false
  def parse_pulse_chars(opts) do
    case Keyword.get(opts, :chars) || Keyword.get(opts, :pulse_chars) do
      nil -> @default_pulse_chars
      chars_str -> String.split(chars_str, ",") |> Enum.map(&String.trim/1)
    end
  end

  @doc false
  def parse_colors(opts) do
    case Keyword.get(opts, :colors) || Keyword.get(opts, :color) do
      nil -> {:ok, [{0, 180, 216}]}
      colors_str -> parse_colors_list(colors_str)
    end
  end

  defp parse_colors_list(colors_str) do
    colors_str
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {color_str, idx}, {:ok, acc} ->
      case Orchestrator.parse_color(color_str) do
        {:ok, rgb} ->
          {:cont, {:ok, [rgb | acc]}}

        {:error, error_msg} ->
          {:halt, {:error, "Invalid color at position #{idx + 1}: '#{color_str}'. #{error_msg}"}}
      end
    end)
    |> case do
      {:ok, colors} -> {:ok, Enum.reverse(colors)}
      error -> error
    end
  end

  @doc false
  def parse_direction("in"), do: :in
  def parse_direction("out"), do: :out

  def parse_direction(other) do
    IO.puts(:stderr, "Error: --direction must be 'in' or 'out', got '#{other}'")
    exit({:shutdown, 1})
  end

  @doc false
  def parse_content_type("text"), do: :text
  def parse_content_type("image"), do: :image

  def parse_content_type(other) do
    IO.puts(:stderr, "Error: --content-type must be 'text' or 'image', got '#{other}'")
    exit({:shutdown, 1})
  end
end
