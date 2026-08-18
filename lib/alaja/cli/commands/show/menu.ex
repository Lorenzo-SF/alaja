defmodule Alaja.CLI.Commands.Show.Menu do
  @moduledoc "`alaja menu` — Display an interactive selection menu."

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Printer

  @help_data [
    title: "Alaja Menu",
    subtitle: "Display an interactive selection menu",
    usage:
      "alaja menu [--header T] <item1> <item2> ... <itemN> [--color C] [--align left|center|right]",
    description:
      "Interactive menu: the first arg is the header (or use `--header`), the rest are the choices. The selected item is printed to stdout.",
    options: [
      {:header, :string, nil, "Header / prompt (defaults to first positional)"},
      {:color, :string, nil, "Color of the menu items"},
      {:align, :string, "left", "Alignment: left, center, right"}
    ],
    examples: [
      {"Simple choice", "alaja menu build test deploy"},
      {"With header", "alaja menu --header \"Pick environment\" dev staging prod"},
      {"Coloured", "alaja menu \"Pick\" A B C --color cyan"},
      {"Many options", "alaja menu --header \"Pick a port\" 80 443 3000 5432 6379 8080"},
      {"Use in script", "env=$(alaja menu dev staging prod); echo \"deploying to $env\""}
    ]
  ]

  @doc "Runs the `alaja menu` command from raw argv — shows an interactive menu and prints the selected item."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [header: :string, color: :string, align: :string]
      )

    if global.help do
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
    case Alaja.CLI.Color.parse(s) do
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

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
