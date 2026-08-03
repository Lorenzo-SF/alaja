defmodule Alaja.CLI.Commands.Show.Image do
  @moduledoc "`alaja image` — Display images in terminal."

  @help_data [
    title: "Alaja Image",
    subtitle: "Display images in the terminal",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts

  alias Alaja.ImageRenderer

  @doc "Runs the `alaja image` command from raw argv; picks ascii or imgcat based on protocol and renders the image."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, _, _} =
      OptionParser.parse(rest,
        switches: [
          path: :string,
          width: :integer,
          height: :integer,
          protocol: :string,
          to_ascii_art: :boolean,
          ascii_chars: :string,
          ascii_color: :boolean,
          ascii_saturation: :float,
          ascii_style: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      path = Keyword.get(opts, :path)
      render_image(path, opts, global)
    end
  end

  defp render_image(path, opts, global) do
    cond do
      is_nil(path) or path == "" ->
        help()

      not File.exists?(path) ->
        IO.puts(:stderr, "Error: File not found: #{path}")
        :ok

      global.raw and (global.pos_x == 0 and global.pos_y == 0) ->
        IO.puts(:stderr, "Error: --raw requires both --pos-x and --pos-y")
        :ok

      Keyword.get(opts, :to_ascii_art, false) ->
        render_ascii(path, opts, global)

      true ->
        render(path, opts, global)
    end
  end

  defp render_ascii(path, opts, global) do
    if global.raw do
      IO.write("\e[#{global.pos_y + 1};#{global.pos_x + 1}H")
    end

    render_opts = [
      width: Keyword.get(opts, :width, 40),
      height: Keyword.get(opts, :height, 0),
      ascii_style: parse_ascii_style(Keyword.get(opts, :ascii_style)),
      ascii_chars: Keyword.get(opts, :ascii_chars),
      ascii_color: Keyword.get(opts, :ascii_color, true),
      ascii_saturation: Keyword.get(opts, :ascii_saturation, 1.0)
    ]

    case ImageRenderer.render_ascii_art(path, render_opts) do
      :ok -> :ok
      :unsupported -> IO.puts(:stderr, "Could not render ASCII art (install python3 + Pillow)")
    end
  end

  defp parse_ascii_style(nil), do: nil

  defp parse_ascii_style("blocks"), do: :blocks
  defp parse_ascii_style("detailed"), do: :detailed
  defp parse_ascii_style("simple"), do: :simple
  defp parse_ascii_style("braille"), do: :braille
  defp parse_ascii_style(_), do: nil

  @dialyzer {:nowarn_function, {:render, 3}}
  defp render(path, opts, global) do
    if global.raw do
      IO.write("\e[#{global.pos_y + 1};#{global.pos_x + 1}H")
    end

    render_opts =
      [
        align: global.align,
        width: Keyword.get(opts, :width, 40),
        height: Keyword.get(opts, :height, 20)
      ]
      |> maybe_put(:protocol, protocol_opt(opts))

    case ImageRenderer.render_file(path, render_opts) do
      :ok -> :ok
      :unsupported -> IO.puts(:stderr, "Terminal does not support image rendering")
      {:error, reason} -> IO.puts(:stderr, "Error: #{inspect(reason)}")
    end
  end

  defp protocol_opt(opts) do
    case Keyword.get(opts, :protocol) do
      nil ->
        nil

      p ->
        case Alaja.Helpers.safe_string_to_atom(p) do
          {:ok, atom} -> atom
          {:error, _} -> nil
        end
    end
  end

  defp maybe_put(list, _key, nil), do: list
  defp maybe_put(list, key, value), do: Keyword.put(list, key, value)

  @spec help() :: keyword()
  def help, do: @help_data
end
