defmodule Alaja.CLI.Commands.Show.Pulsar.Data do
  @moduledoc false

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
      colors_str -> Alaja.CLI.Color.parse_list(colors_str)
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
