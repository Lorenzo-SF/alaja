# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Alaja.CLI.Commands.Show.Gradient do
  @moduledoc "`alaja gradient` — Display gradient-colored text."

  @help_data [
    title: "Alaja Gradient",
    subtitle: "Display gradient-colored text",
    size: :small
  ]

  alias Alaja.CLI.{GlobalOpts, Parser}
  alias Alaja.Components.{Gradient, Header, Separator, Table}
  alias Alaja.Printer

  @doc """
  Runs the gradient command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          from: :string,
          to: :string,
          colors: :string,
          direction: :string,
          bg: :boolean,
          text_color: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      case positional do
        [] -> help()
        lines -> render(Enum.join(lines, "\n"), opts, global)
      end
    end
  end

  defp render(text, opts, global) do
    direction =
      case Alaja.Helpers.safe_string_to_atom(Keyword.get(opts, :direction, "left_to_right")) do
        {:ok, atom} -> atom
        {:error, _} -> :left_to_right
      end

    bg = Keyword.get(opts, :bg, false)
    text_color = parse_color(Keyword.get(opts, :text_color))
    colors_str = Keyword.get(opts, :colors)

    render_opts = [
      direction: direction,
      bg: bg,
      text_color: text_color,
      colors: colors_str,
      from: Keyword.get(opts, :from, "#FF0000"),
      to: Keyword.get(opts, :to, "#0000FF")
    ]

    result = Gradient.render(text, render_opts)
    Printer.print_raw(result, printer_opts(global))
  end

  defp parse_color(nil), do: nil
  defp parse_color(s), do: Parser.parse_color_opt(s)

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc """
  Prints help for the gradient command.
  """
  @spec help() :: :ok
  def help, do: @help_data
end
