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
      "alaja header <title[;line2;...]> [--subtitle S] [--size tiny|small|medium|large|<int>] [--color C[|C|...]] [--subtitle-color C[|C|...]] [--separator-char CHAR] [--separator-color C[|C|...]] [--separator-length N]",
    description: """
    Renders a styled header with optional subtitle.

    The title (and subtitle) may contain several lines separated by `;`
    inside a quoted argument. When several colours are provided via
    `--color` (or `--subtitle-color`) the list is matched positionally
    against the lines of the corresponding text.

    `--size` accepts one of the named presets (`tiny` = 1/8, `small` =
    1/4, `medium` = 1/2, `large` = full terminal width) or a positive
    integer for an exact column width.
    """,
    options: [
      {:subtitle, :string, nil, "Subtitle text (use `;` to split lines)"},
      {:size, :string, "medium", "Size: tiny, small, medium, large, or positive integer"},
      {:color, :string, nil,
       "Title colour (<format>:<code> or list of colours separated by `|`; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: rgb:255,0,0|theme:primary"},
      {:"subtitle-color", :string, nil,
       "Subtitle colour (<format>:<code> or list of colours separated by `|`; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: hex:ff0000|theme:secondary"},
      {:separator_char, :string, nil, "Character used for decorative lines"},
      {:"separator-color", :string, nil,
       "Colour of the decorative lines (<format>:<code> or list separated by `|`; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: theme:primary"},
      {:separator_length, :integer, nil,
       "Override the length of the decorative lines (defaults to terminal width)"}
    ],
    examples: [
      {"Simple title", "alaja header \"Release 3.0\""},
      {"Title + subtitle", "alaja header \"Release 3.0\" --subtitle \"stable\""},
      {"Large banner", "alaja header \"Alaja\" --size large --color magenta"},
      {"Coloured subtitle",
       "alaja header \"Build\" --subtitle \"main branch\" --subtitle-color grey"},
      {"Multiple colours per line",
       "alaja header \"line1;line2;line3\" --color \"hex:#fa00ce|theme:primary|theme:ternary\""},
      {"Custom separator",
       "alaja header \"Release\" --separator-char \"*\" --separator-color theme:secondary"},
      {"Width pinned to terminal", "alaja header \"Welcome\" --size large"}
    ]
  ]

  @doc """
  Runs the header command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    switches =
      [
        subtitle: :string,
        size: :string,
        color: :string
      ] ++
        [
          {String.to_atom("subtitle-color"), :string},
          {String.to_atom("separator-char"), :string},
          {String.to_atom("separator-color"), :string},
          {String.to_atom("separator-length"), :integer}
        ]

    {opts, positional, _} = OptionParser.parse(rest, switches: switches)

    if global.help do
      help()
    else
      title = Enum.join(positional, " ")
      if title == "", do: help(global), else: render(title, opts, global)
    end
  end

  defp render(title, opts, global) do
    subtitle_color =
      Color.parse_list_or_nil(Keyword.get(opts, :"subtitle-color")) ||
        Color.parse_or_nil(Keyword.get(opts, :"subtitle-color"))

    separator_color =
      Color.parse_list_or_nil(Keyword.get(opts, :"separator-color")) ||
        Color.parse_or_nil(Keyword.get(opts, :"separator-color"))

    rendered =
      HeaderComp.render(title,
        subtitle: Keyword.get(opts, :subtitle),
        size: parse_size(Keyword.get(opts, :size, "medium")),
        color:
          Color.parse_list_or_nil(Keyword.get(opts, :color)) ||
            Color.parse_or_nil(Keyword.get(opts, :color)),
        subtitle_color: subtitle_color,
        separator_char: Keyword.get(opts, :"separator-char"),
        separator_color: separator_color,
        separator_length: Keyword.get(opts, :"separator-length")
      )

    Printer.print_raw(rendered, printer_opts(global))
  end

  # Accepts named presets (tiny/small/medium/large) and positive integer
  # strings (e. 80 for exact column width). Anything else falls back to
  # :medium.
  defp parse_size(str) do
    case Integer.parse(str) do
      {n, ""} when n > 0 ->
        n

      _ ->
        case Alaja.Helpers.safe_string_to_atom(str) do
          {:ok, atom} -> atom
          {:error, _} -> :medium
        end
    end
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc "Prints help for the header command."
  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
