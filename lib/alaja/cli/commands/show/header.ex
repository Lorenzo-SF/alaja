defmodule Alaja.CLI.Commands.Show.Header do
  @moduledoc "`alaja header` — Display styled headers."

  alias Alaja.CLI.Color
  alias Alaja.CLI.Commands.Base
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Header, as: HeaderComp
  alias Alaja.Printer

  @help_data [
    title: "Alaja Header",
    subtitle: "Display styled headers with optional subtitle",
    usage:
      "alaja header <title[;line2;...]> [--subtitle S] [--size small|medium|large] [--color C[|C|...]] [--subtitle-color C[|C|...]] [--separator-char CHAR] [--separator-color C[|C|...]] [--separator-length N] [--width N]",
    description: """
    Renders a styled header with optional subtitle.

    The title (and subtitle) may contain several lines separated by `;`
    inside a quoted argument. When several colours are provided via
    `--color` (or `--subtitle-color`) the list is matched positionally
    against the lines of the corresponding text.
    """,
    options: [
      {:subtitle, :string, nil, "Subtitle text (use `;` to split lines)"},
      {:size, :string, "medium", "Size: small, medium, large"},
      {:color, :string, nil,
       "Title colour (<format>:<code> or list of colours separated by `|`; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: rgb:255,0,0|theme:primary"},
      {:subtitle_color, :string, nil,
       "Subtitle colour (<format>:<code> or list of colours separated by `|`; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: hex:ff0000|theme:secondary"},
      {:separator_char, :string, nil, "Character used for decorative lines"},
      {:separator_color, :string, nil,
       "Colour of the decorative lines (<format>:<code> or list separated by `|`; formats: rgb, argb, hex, xterm, cmyk, hsl, hsv, hwb, theme). Example: theme:primary"},
      {:separator_length, :integer, nil,
       "Override the length of the decorative lines (defaults to terminal width)"},
      {:width, :integer, 80, "Total width in characters (default: terminal width)"}
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

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          subtitle: :string,
          size: :string,
          color: :string,
          subtitle_color: :string,
          separator_char: :string,
          separator_color: :string,
          separator_length: :integer,
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
        color:
          Color.parse_list_or_nil(Keyword.get(opts, :color)) ||
            Color.parse_or_nil(Keyword.get(opts, :color)),
        subtitle_color:
          Color.parse_list_or_nil(Keyword.get(opts, :subtitle_color)) ||
            Color.parse_or_nil(Keyword.get(opts, :subtitle_color)),
        separator_char: Keyword.get(opts, :separator_char),
        separator_color:
          Color.parse_list_or_nil(Keyword.get(opts, :separator_color)) ||
            Color.parse_or_nil(Keyword.get(opts, :separator_color)),
        separator_length: Keyword.get(opts, :separator_length),
        width: width_or_terminal(Keyword.get(opts, :width))
      )

    Printer.print_raw(rendered, printer_opts(global))
  end

  defp width_or_terminal(nil), do: Base.term_width()
  defp width_or_terminal(w) when is_integer(w), do: w
  defp width_or_terminal(_), do: Base.term_width()

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  @doc "Prints help for the header command."
  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
