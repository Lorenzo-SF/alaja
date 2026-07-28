defmodule Alaja.CLI.Commands.Show.Header do
  @moduledoc "`alaja header` — Display styled headers."

  @help_data [
    title: "Alaja Header",
    subtitle: "Display styled headers with optional subtitle",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.Header, as: HeaderComp

  alias Alaja.Printer

  @doc """
  Runs the header command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          subtitle: :string,
          size: :string,
          color: :string,
          subtitle_color: :string,
          width: :integer
        ]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      title = Enum.join(positional, " ")
      if title == "", do: help(), else: render(title, opts, global)
    end
  end

  defp render(title, opts, global) do
    rendered =
      HeaderComp.render(title,
        subtitle: Keyword.get(opts, :subtitle),
        size:
          case Alaja.Helpers.safe_string_to_atom(Keyword.get(opts, :size, "medium")) do
            {:ok, atom} -> atom
            {:error, _} -> :medium
          end,
        color: parse_color(Keyword.get(opts, :color)),
        subtitle_color: parse_color(Keyword.get(opts, :subtitle_color)),
        width: Keyword.get(opts, :width, 80)
      )

    Printer.print_raw(rendered, printer_opts(global))
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc """
  Prints help for the header command.
  """
  @spec help() :: :ok
  def help, do: @help_data
end
