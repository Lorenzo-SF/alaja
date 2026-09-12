defmodule Alaja.CLI.Commands.Show.Bar do
  @moduledoc "`alaja bar` — Display progress bars."

  alias Alaja.Buffer
  alias Alaja.CLI.Color
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Bar, as: BarComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Bar",
    subtitle: "Display progress bars",
    usage:
      "alaja bar <value> [--max N] [--label T] [--width N] [--filled-char C] [--empty-char C] [--filled-color C] [--empty-color C] [--show-percent]",
    description: """
    Renders a single horizontal progress bar. `value` is the absolute
    progress; `max` is the upper bound. The bar fills proportionally.
    """,
    options: [
      {:max, :integer, 100, "Maximum value (default 100)"},
      {:label, :string, nil, "Optional label drawn to the left of the bar"},
      {:width, :integer, 40, "Bar width in characters"},
      {:filled_char, :string, "▓", "Character used for the filled portion"},
      {:empty_char, :string, "░", "Character used for the empty portion"},
      {:filled_color, :string, "success", "Color of the filled portion"},
      {:empty_color, :string, "background", "Color of the empty portion"},
      {:show_percent, :boolean, true, "Show the percent label at the right"}
    ],
    examples: [
      {"Plain bar", "alaja bar 60"},
      {"With label", "alaja bar 60 --max 100 --label build"},
      {"Custom chars", "alaja bar 42 --max 100 --filled-char � --empty-char ░"},
      {"Custom colours", "alaja bar 80 --filled-color green --empty-color grey"},
      {"Hide percent", "alaja bar 30 --no-show-percent"},
      {"Wide bar for dashboards", "alaja bar 75 --max 100 --width 60 --label \"deploy\""},
      {"Compact ASCII", "alaja bar 50 --filled-char \"#\" --empty-char \".\" --width 20"}
    ]
  ]

  @doc "Runs the `alaja bar` command from raw argv; prints help on `--help` or no value."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          max: :integer,
          label: :string,
          width: :integer,
          filled_char: :string,
          empty_char: :string,
          filled_color: :string,
          empty_color: :string,
          show_percent: :boolean
        ]
      )

    if global.help do
      help()
    else
      case positional do
        [value_str | _] -> render(value_str, opts, global)
        [] -> help()
      end
    end
  end

  defp render(value_str, opts, global) do
    value =
      case Integer.parse(value_str) do
        {n, ""} ->
          n

        _ ->
          IO.puts(:stderr, "Error: value must be an integer, got '#{value_str}'")
          exit({:shutdown, 1})
      end

    max = Keyword.get(opts, :max, 100)
    label = Keyword.get(opts, :label)
    width = Keyword.get(opts, :width, 40)

    bar_opts =
      [
        label: label,
        width: width,
        filled_char: Keyword.get(opts, :filled_char),
        empty_char: Keyword.get(opts, :empty_char),
        filled_color: Color.parse_or_nil(Keyword.get(opts, :filled_color)),
        empty_color: Color.parse_or_nil(Keyword.get(opts, :empty_color)),
        show_percent: Keyword.get(opts, :show_percent, true)
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    rendered = BarComp.render(value, max, bar_opts)
    rendered_iodata = Buffer.to_iodata(rendered)
    output = if global.raw, do: rendered_iodata, else: ["  ", rendered_iodata]
    Printer.print_raw(output, printer_opts(global))
  end

  # parse_color/1 delegates to Alaja.CLI.Color.parse_or_nil/1

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
