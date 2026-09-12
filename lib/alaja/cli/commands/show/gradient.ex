defmodule Alaja.CLI.Commands.Show.Gradient do
  @moduledoc "`alaja gradient` — Display gradient-colored text."

  alias Alaja.CLI.Color
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Gradient, as: GradComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Gradient",
    subtitle: "Gradient-colored text (multi-color support)",
    usage:
      "alaja gradient <text[;line2[;line3...]]> [--from C] [--to C] [--colors C[|C[|C...]]] [--direction left_to_right|right_to_left|up_to_down|down_to_up] [--bg] [--color C]",
    description: """
    Renders text with a gradient color treatment. Specify either
    `--from` and `--to` (linear interpolation) or a `--colors` list
    specifying the gradient stops.

    To apply the gradient to several lines at once, separate the lines
    with `;` (e.g. `"line1;line2;line3"`) and combine with the vertical
    directions (`up_to_down` / `down_to_up`).
    """,
    options: [
      {:from, :string, nil,
       "Start color (<format>:<code>; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: rgb:255,0,0"},
      {:to, :string, nil,
       "End color (<format>:<code>; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: hex:ff0000"},
      {:colors, :string, nil,
       "List of gradient stops separated by `|` (NOT commas; e.g. hex:ff0000|hex:00ff00|hex:0000ff; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: theme:primary|theme:secondary|rgb:0,255,0"},
      {:direction, :string, "right_to_left",
       "Gradient direction: right_to_left (default), left_to_right, up_to_down (multi-line only), down_to_up (multi-line only)"},
      {:bg, :boolean, false, "Apply the gradient to the background instead of the foreground"},
      {:color, :string, nil, "Override the gradient with a single text color"}
    ],
    examples: [
      {"Two-stop horizontal", "alaja gradient \"alaja\" --from hex:ff6b6b --to hex:4ecdc4"},
      {"Three-stop rainbow",
       "alaja gradient \"ship it\" --colors hex:ff0000|hex:00ff00|hex:0000ff"},
      {"Vertical gradient",
       "alaja gradient \"release\" --from #FFFF00 --to hex:ff00ff --direction vertical"},
      {"Background gradient", "alaja gradient \"urgent\" --from red --to yellow --bg"},
      {"Single-colour override", "alaja gradient \"quiet\" --color grey"},
      {"Brand title", "alaja gradient \"CACAFUTI\" --colors hex:7aa2f7|hex:f5c2e7|hex:abe9b3"},
      {"Multiline vertical",
       "alaja gradient \"alaja;line2;line3\" --from hex:ff0000 --to hex:0000ff --direction down_to_up"}
    ]
  ]

  @doc "Runs the gradient command."
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
          color: :string
        ]
      )

    if global.help do
      help()
    else
      text = Enum.join(positional, " ")
      render(text, opts, global)
    end
  end

  defp render(text, opts, global) do
    grad_opts =
      [
        from: Color.parse_or_nil(Keyword.get(opts, :from)),
        to: Color.parse_or_nil(Keyword.get(opts, :to)),
        # Pass the raw string to the back-end; the component parses it.
        colors: Keyword.get(opts, :colors),
        direction: parse_direction(Keyword.get(opts, :direction)),
        bg: Keyword.get(opts, :bg, false),
        text_color: Color.parse_or_nil(Keyword.get(opts, :color))
      ]
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

    # `;` inside a quoted argument is a user-friendly way to split the
    # text into multiple lines. Translate it to a real newline so the
    # component's `split_lines/1` picks it up; vertical directions need
    # this to colour each line independently.
    text = String.replace(text, ";", "\n")

    rendered = GradComp.render(text, grad_opts)
    Printer.print_raw(rendered, printer_opts(global))
  end

  # parse_color/1 delegates to Alaja.CLI.Color.parse_or_nil/1

  defp parse_direction(nil), do: :right_to_left
  defp parse_direction("right_to_left"), do: :right_to_left
  defp parse_direction("left_to_right"), do: :left_to_right
  defp parse_direction("up_to_down"), do: :up_to_down
  defp parse_direction("down_to_up"), do: :down_to_up

  defp parse_direction(other) do
    IO.puts(
      :stderr,
      "Error: --direction must be one of left_to_right, right_to_left, up_to_down, down_to_up, got '#{other}'"
    )

    exit({:shutdown, 1})
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
