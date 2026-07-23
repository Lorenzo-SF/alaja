defmodule Alaja.CLI.Commands.Show.Menu do
  @moduledoc "`alaja menu` — Display an interactive selection menu."

  @help_data [
    title: "Alaja Menu",
    subtitle: "Display an interactive selection menu",
    size: :small
  ]

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.{Header, Separator, Table}
  alias Alaja.Printer

  @doc "Runs the `alaja menu` command from raw argv — shows an interactive menu and prints the selected item."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [header: :string, color: :string, align: :string]
      )

    if global.help or Keyword.get(opts, :help, false) do
      help()
    else
      header = Keyword.get(opts, :header) || Enum.at(items, 0)
      menu_items = if Keyword.get(opts, :header), do: items, else: Enum.drop(items, 1)
      color = parse_color(Keyword.get(opts, :color))
      align = parse_align(Keyword.get(opts, :align))

      if is_nil(header) or menu_items == [] do
        help()
      else
        options = Enum.map(menu_items, &{&1, &1})

        answer =
          Printer.Interactive.question_with_options("Selection", options,
            color: color,
            align: align
          )

        IO.write(to_string(answer))
      end
    end
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp parse_align(nil), do: :left
  defp parse_align(a) when is_atom(a), do: a

  defp parse_align(s) when is_binary(s) do
    case Alaja.Helpers.safe_string_to_atom(s) do
      {:ok, atom} -> atom
      {:error, _} -> :left
    end
  end

  @spec help() :: :ok
  def help, do: @help_data
end
