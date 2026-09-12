defmodule Alaja.CLI.Commands.Show.Message.Handler do
  @moduledoc """
  Thin wrapper for the `message` command.

  All parsing/formatting logic lives in `Alaja.Structures.ChunkText` and
  `Alaja.Structures.MessageInfo`.  This module just dispatches.
  """

  alias Alaja.CLI.Color
  alias Alaja.Structures.{ChunkText, MessageInfo}

  @doc """
  Runs the message command with parsed opts.
  """
  @spec run(map()) :: :ok
  def run(opts) do
    text = build_text(opts)
    type = opts[:type]

    if text == "" do
      :ok
    else
      do_render(text, type, opts)
    end
  end

  defp build_text(opts) do
    # Concatenate text + text2 + text3 with newline separators.
    [opts[:text], opts[:text2], opts[:text3]]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp do_render(_text, type, opts) when not is_nil(type) do
    # Typed message (success, error, etc.)
    color = parse_color(opts[:color]) || default_color_for_type(type)
    bg_color = parse_color(opts[:bg_color])

    chunk = %ChunkText{text: opts[:text] || "", color: color, bg_color: bg_color}
    info = %MessageInfo{type: String.to_atom(type), chunks: [chunk]}
    Alaja.print_message(info)
    :ok
  end

  defp do_render(_text, nil, opts) do
    # Generic message with chunk styling.
    color = parse_color(opts[:color])
    bg_color = parse_color(opts[:bg_color])

    chunk = %ChunkText{text: opts[:text] || "", color: color, bg_color: bg_color}
    Alaja.print_chunk(chunk)
    :ok
  end

  defp parse_color(nil), do: nil
  defp parse_color(""), do: nil
  defp parse_color(s) when is_binary(s), do: Color.parse(s)

  defp default_color_for_type("success"), do: {:green, :default}
  defp default_color_for_type("error"), do: {:red, :default}
  defp default_color_for_type("warning"), do: {:yellow, :default}
  defp default_color_for_type("info"), do: {:cyan, :default}
  defp default_color_for_type("debug"), do: {:white, :default}
  defp default_color_for_type(_), do: {:default, :default}
end
