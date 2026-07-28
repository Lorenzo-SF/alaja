defmodule Alaja.CLI.Commands.Show.Pulsar do
  @moduledoc """
  `alaja pulsar` — Display pulsar/radar animation with gradient wave effect.

  Creates a rectangular animation with text in the center surrounded by
  pulsing characters that create a radar/wave effect.
  """

  @help_data [
    title: "Alaja Pulsar",
    subtitle: "Pulsar/radar animation with gradient wave effect",
    size: :small
  ]

  alias Alaja.CLI.Commands.Show.Pulsar.{Data, Renderer}
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.Parser

  @doc "Runs the `alaja pulsar` command — renders the radar/pulse animation for `--duration` ms."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          text: :string,
          width: :integer,
          height: :integer,
          pulse_chars: :string,
          colors: :string,
          color: :string,
          speed: :integer,
          align: :string,
          chars: :string,
          direction: :string,
          content_position_x: :integer,
          content_position_y: :integer,
          content_type: :string,
          image_path: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      text = Keyword.get(opts, :text) || Enum.join(positional, " ")

      if text == "" do
        help()
      else
        run_pulsar(text, opts, global)
      end
    end
  end

  defp run_pulsar(text, opts, global) do
    width = Keyword.get(opts, :width, 40)
    height = Keyword.get(opts, :height, 7)
    speed = Keyword.get(opts, :speed, 100)

    pulse_chars = Data.parse_pulse_chars(opts)
    colors_result = Data.parse_colors(opts)

    case colors_result do
      {:ok, colors} ->
        direction = Data.parse_direction(Keyword.get(opts, :direction, "out"))
        align = Parser.parse_align(Keyword.get(opts, :align, "center"))
        content_type = Data.parse_content_type(Keyword.get(opts, :content_type, "text"))
        content_x = Keyword.get(opts, :content_position_x)
        content_y = Keyword.get(opts, :content_position_y)

        pulsar_opts = [
          width: width,
          height: height,
          pulse_chars: pulse_chars,
          colors: colors,
          speed: speed,
          align: align,
          direction: direction,
          content_type: content_type,
          content_position_x: content_x,
          content_position_y: content_y,
          image_path: Keyword.get(opts, :image_path),
          text: text
        ]

        if global.verbose do
          Renderer.print_verbose_frames(text, pulsar_opts)
        else
          Renderer.run_animation(text, pulsar_opts, global)
        end

      {:error, error_msg} ->
        IO.puts(:stderr, "Error: #{error_msg}")
        exit({:shutdown, 1})
    end
  end

  @spec help() :: :ok
  def help, do: @help_data
end
