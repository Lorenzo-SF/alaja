defmodule Alaja.CLI.Commands.Show.Header do
  @moduledoc "`alaja header` — Display styled headers."

  alias Alaja.CLI.Color
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Header, as: HeaderComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Header",
    subtitle: "Display styled headers with optional subtitle",
    usage:
      "alaja header <title> [--subtitle T] [--size small|medium|large] [--color C] [--subtitle-color C] [--width N]",
    description:
      "Renders a styled header with optional subtitle. The title is drawn from the first positional argument.",
    options: [
      {:subtitle, :string, nil, "Subtitle text below the title"},
      {:size, :string, "medium", "Size: small, medium, large"},
      {:color, :string, nil, "Title color"},
      {:subtitle_color, :string, nil, "Subtitle color"},
      {:width, :integer, 80, "Width in characters"}
    ],
    examples: [
      {"Simple title", "alaja header \"Release 3.0\""},
      {"Title + subtitle", "alaja header \"Release 3.0\" --subtitle \"stable\""},
      {"Large banner", "alaja header \"Alaja\" --size large --color magenta"},
      {"Coloured subtitle",
       "alaja header \"Build\" --subtitle \"main branch\" --subtitle-color grey"},
      {"Custom width", "alaja header \"Release\" --width 40"},
      {"Pinned to terminal width", "alaja header \"Welcome\" --size large --width 120"}
    ]
  ]

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

    if global.help do
      help()
    else
      title = Enum.join(positional, " ")
      if title == "", do: help(global), else: render(title, opts, global)
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
        color: Color.parse_or_nil(Keyword.get(opts, :color)),
        subtitle_color: Color.parse_or_nil(Keyword.get(opts, :subtitle_color)),
        width: Keyword.get(opts, :width, 80)
      )

    Printer.print_raw(rendered, printer_opts(global))
  end

  # parse_color/1 delegates to Alaja.CLI.Color.parse_or_nil/1

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc "Prints help for the header command."
  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
