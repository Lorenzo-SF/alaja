defmodule Alaja.CLI.Commands.Show.Breadcrumbs do
  @moduledoc "`alaja breadcrumbs` — Display navigation breadcrumbs."

  alias Alaja.Buffer
  alias Alaja.CLI.Color
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
      "Draws a horizontal trail of items separated by a separator character. The last item is highlighted as `current`. All switches are kebab-case (`--separator-color`, not `--separator_color`).",
    options: [
      {:separator, :string, "›", "Separator character between items"},
      {:color, :string, nil, "Color for items (item_color in back)"},
      {:"separator-color", :string, nil, "Color of the separator"},
      {:"current-color", :string, nil, "Color of the last (current) item"}
    ],
    examples: [
      {"Code path", "alaja breadcrumbs home lib alaja"},
      {"Deployment env trail", "alaja breadcrumbs dev staging prod"},
      {"Arrow separator", "alaja breadcrumbs dev staging prod --separator \"→\""},
      {"Slash separator (URL-style)", "alaja breadcrumbs home users alice --separator \"/\""},
      {"Coloured trail",
       "alaja breadcrumbs build test deploy --color cyan --current-color green"},
      {"Custom separator colour", "alaja breadcrumbs repo branch commit --separator-color grey"}
    ]
  ]

  @doc "Runs the `alaja breadcrumbs` command from raw argv; prints help on `--help` or no items."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    switches =
      [
        separator: :string,
        color: :string
      ] ++
        [
          {String.to_atom("separator-color"), :string},
          {String.to_atom("current-color"), :string}
        ]

    {opts, items, _} = OptionParser.parse(rest, switches: switches)

    if global.help or items == [] do
      help()
    else
      bc_opts =
        [
          separator: Keyword.get(opts, :separator),
          item_color: Color.parse_list_or_nil(Keyword.get(opts, :color)),
          separator_color: Color.parse_list_or_nil(Keyword.get(opts, :"separator-color")),
          current_color: Color.parse_list_or_nil(Keyword.get(opts, :"current-color"))
        ]
        |> Enum.reject(fn {_, v} -> is_nil(v) end)

      rendered = BCComp.render(items, bc_opts)
      rendered_iodata = if is_list(rendered), do: rendered, else: Buffer.to_iodata(rendered)

      output = if global.raw, do: rendered_iodata, else: ["  ", rendered_iodata]
      Printer.print_raw(output, printer_opts(global))
    end
  end

  # parse_color/1 delegates to Alaja.CLI.Color.parse_or_nil/1

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
