defmodule Alaja.CLI.Commands.Show.Pulsar.Handler do
  @moduledoc """
  Thin wrapper for the `pulsar` command.

  This module is a pure dispatcher — all parsing logic lives in
  `Alaja.Components.Pulsar.parse_*` helpers, all animation logic lives
  in `Alaja.Components.Pulsar.run/3`.

  ## Why a separate Handler module

  The `Alaja.CLI.Definition` DSL requires `run` to be a 1-arity function.
  Putting the handler in a separate module keeps the CLI declaration
  clean (no inline business logic) and makes the handler independently
  testable.
  """

  alias Alaja.Components.Pulsar

  @doc """
  Runs the pulsar command with parsed opts.

  Returns `:ok` on success, prints help if text is missing.
  """
  @spec run(map()) :: :ok | no_return()
  def run(opts) do
    text = Keyword.get(opts, :text) || ""

    if text == "" do
      IO.puts(:stderr, "Error: missing <text> argument")
      IO.puts(:stderr, "Usage: alaja pulsar <text> [options]")
      exit({:shutdown, 1})
    else
      run_pulsar(text, opts)
    end
  end

  defp run_pulsar(text, opts) do
    pulse_chars = Pulsar.parse_pulse_chars(opts[:chars])
    colors_result = parse_colors(opts)

    case colors_result do
      {:ok, colors} ->
        {:ok, direction} = Pulsar.parse_direction(opts[:direction] || "out")
        {:ok, content_type} = Pulsar.parse_content_type(opts[:content_type] || "text")

        pulsar_opts = [
          width: opts[:width],
          height: opts[:height],
          pulse_chars: pulse_chars,
          colors: colors,
          speed: opts[:speed],
          align: opts[:align],
          direction: direction,
          content_type: content_type,
          content_position_x: opts[:"content-position-x"],
          content_position_y: opts[:"content-position-y"],
          image_path: opts[:image_path],
          duration: opts[:duration],
          text: text
        ]

        Pulsar.run(text, pulsar_opts, [])

      {:error, error_msg} ->
        IO.puts(:stderr, "Error: #{error_msg}")
        exit({:shutdown, 1})
    end
  end

  defp parse_colors(opts) do
    case opts[:colors] || opts[:color] do
      nil -> {:ok, [{0, 180, 216}]}
      colors_str -> Alaja.CLI.Color.parse_list(colors_str)
    end
  end
end
