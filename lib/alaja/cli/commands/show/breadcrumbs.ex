defmodule Alaja.CLI.Commands.Show.Breadcrumbs do
  @moduledoc "`alaja breadcrumbs` — Display navigation breadcrumbs."

  alias Alaja.Buffer
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Breadcrumbs, as: BCComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Breadcrumbs",
    subtitle: "Display navigation breadcrumbs",
    usage:
      "alaja breadcrumbs <item1> <item2> ... <itemN> [--separator C] [--color C] [--separator-color C] [--current-color C]",
    description:
      "Draws a horizontal trail of items separated by a separator character. The last item is highlighted as `current`.",
    options: [
      {:separator, :string, "›", "Separator character between items"},
      {:color, :string, nil, "Color for items (item_color in back)"},
      {:separator_color, :string, nil, "Color of the separator"},
      {:current_color, :string, nil, "Color of the last (current) item"}
    ]
  ]

  @doc "Runs the `alaja breadcrumbs` command from raw argv; prints help on `--help` or no items."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, items, _} =
      OptionParser.parse(rest,
        switches: [
          separator: :string,
          color: :string,
          separator_color: :string,
          current_color: :string
        ]
      )

    if global.help or Keyword.get(opts, :help, false) or items == [] do
      help()
    else
      bc_opts =
        [
          separator: Keyword.get(opts, :separator),
          item_color: parse_color(Keyword.get(opts, :color)),
          separator_color: parse_color(Keyword.get(opts, :separator_color)),
          current_color: parse_color(Keyword.get(opts, :current_color))
        ]
        |> Enum.reject(fn {_, v} -> is_nil(v) end)

      rendered = BCComp.render(items, bc_opts)
      rendered_iodata = if is_list(rendered), do: rendered, else: Buffer.to_iodata(rendered)

      output = if global.raw, do: rendered_iodata, else: ["  ", rendered_iodata]
      Printer.print_raw(output, printer_opts(global))
    end
  end

  defp parse_color(nil), do: nil

  defp parse_color(s) do
    case Pote.Orchestrator.parse_color(s) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help() :: :ok
  def help, do: HelpFormatter.render(@help_data)
end
