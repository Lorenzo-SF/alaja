defmodule Alaja.CLI.HelpFormatter do
  @moduledoc """
  Renders command-specific help output.

  Each command module exposes a `help/0` function that returns a keyword
  list with the following keys:

      * `:title` — required. Header title.
      * `:subtitle` — optional. Smaller subtitle below the title.
      * `:usage` — optional. One-line usage string.
      * `:description` — optional. Multi-line description of the command.
      * `:options` — optional. List of `{name, type, default, textual}` tuples.
      * `:examples` — optional. List of `{comment, command}` tuples rendered
        as `# comment` + `command` blocks.
      * `:globals` — optional boolean (default `true`). If `false`, the
        global options section is omitted.

  On an interactive terminal the sections are shown as three tabs
  (Description / Args / Examples) via `Alaja.CLI.HelpTabs`; when piped
  or redirected everything renders sequentially.
  """

  alias Alaja.CLI.{GlobalOpts, HelpTabs}
  alias Alaja.Components.{Header, Separator, Table}
  alias IO.ANSI

  @cyan {0, 180, 216}
  @green {80, 220, 120}

  @doc "Renders the help keyword list to stdout (plain mode, no tabs)."
  @spec render(keyword()) :: :ok
  def render(help_data), do: render(help_data, %GlobalOpts{})

  @doc "Renders the help keyword list, honouring the caller's global options."
  @spec render(keyword(), GlobalOpts.t() | nil) :: :ok
  def render(help_data, global) do
    global = global || %GlobalOpts{}

    title = Keyword.get(help_data, :title, "Alaja")
    subtitle = Keyword.get(help_data, :subtitle)

    Header.print(title,
      subtitle: subtitle,
      size: :small,
      color: @cyan,
      subtitle_color: {150, 150, 160}
    )

    if HelpTabs.interactive?() do
      HelpTabs.run(build_panels(help_data), global)
    else
      render_flat(help_data)
    end

    :ok
  end

  @doc "Render the global options block."
  @spec render_globals() :: :ok
  def render_globals do
    IO.write(globals_text())
    :ok
  end

  # ---------------------------------------------------------------------------
  # Flat rendering (non-TTY) — keeps the historical section order.
  # ---------------------------------------------------------------------------

  defp render_flat(help_data) do
    usage = Keyword.get(help_data, :usage)
    description = Keyword.get(help_data, :description)
    options = Keyword.get(help_data, :options, [])
    examples = Keyword.get(help_data, :examples, [])
    show_globals = Keyword.get(help_data, :globals, true)

    if usage, do: IO.write(usage_text(usage))
    if description, do: IO.write(description_text(description))

    if options != [], do: IO.write(options_text(options))
    if examples != [], do: IO.write(examples_text(examples))
    if show_globals, do: IO.write(globals_text())

    :ok
  end

  # ---------------------------------------------------------------------------
  # Tab panels (TTY)
  # ---------------------------------------------------------------------------

  defp build_panels(help_data) do
    usage = Keyword.get(help_data, :usage)
    description = Keyword.get(help_data, :description)
    options = Keyword.get(help_data, :options, [])
    examples = Keyword.get(help_data, :examples, [])
    show_globals = Keyword.get(help_data, :globals, true)

    desc_text =
      IO.iodata_to_binary([
        if(usage, do: usage_text(usage), else: []),
        if(description, do: description_text(description), else: [])
      ])

    args_text =
      IO.iodata_to_binary([
        if(options != [], do: options_text(options), else: []),
        if(show_globals, do: ["\n", globals_text()], else: [])
      ])

    examples_text = if examples != [], do: examples_text(examples), else: ""

    [
      {"Description", desc_text},
      {"Args", args_text},
      {"Examples", examples_text}
    ]
    |> Enum.reject(fn {_, text} -> String.trim(IO.iodata_to_binary(text)) == "" end)
    |> Enum.map(fn {label, text} -> %{label: label, render: fn -> text end} end)
  end

  # ---------------------------------------------------------------------------
  # Section builders (text form, shared by flat and panels)
  # ---------------------------------------------------------------------------

  defp usage_text(usage) do
    [
      "\n",
      section_title_text("USAGE", @cyan),
      fg_color({180, 220, 120}),
      "  ",
      usage,
      ANSI.reset(),
      "\n"
    ]
  end

  defp description_text(description) do
    ["\n", description, "\n"]
  end

  defp options_text(options) do
    rows =
      Enum.map(options, fn {name, type, default, desc} ->
        opt_str = format_option(name, type)
        default_str = format_default(default) || ""
        desc_str = desc || ""
        [opt_str, default_str, desc_str]
      end)

    table_text =
      Table.render(
        headers: ["Option", "Default", "Description"],
        rows: rows,
        table_border: :rounded,
        border_color: @green,
        padding: 1,
        headers_color: :cyan,
        headers_effects: [:bold]
      )
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()

    ["\n", section_title_text("OPTIONS", @green), table_text, "\n"]
  end

  defp examples_text(examples) do
    pairs =
      Enum.map(examples, fn {comment, command} ->
        [
          fg_color(@cyan),
          ANSI.bright(),
          "# ",
          comment,
          ANSI.reset(),
          "\n",
          fg_color({180, 220, 120}),
          "  ",
          command,
          ANSI.reset(),
          "\n\n"
        ]
      end)

    ["\n", section_title_text("EXAMPLES", @green), pairs]
  end

  defp globals_text do
    rows = [
      ["--help, -h", "Show help for this command"],
      ["--raw", "Raw positioning mode (display commands)"],
      ["--pos-x N", "X coordinate with --raw"],
      ["--pos-y N", "Y coordinate with --raw"],
      ["--align TYPE", "left, center, right"],
      ["--box", "Wrap output in a bordered box"],
      ["--box-title T", "Box title"],
      ["--box-border S", "Box border style"],
      ["--box-color C", "Box border color"],
      ["--verbose", "Raw ANSI output"],
      ["--quiet, -q", "Suppress output"],
      ["--stdin, -s", "Read input from stdin"]
    ]

    table_text =
      Table.render(
        headers: ["Option", "Description"],
        rows: rows,
        table_border: :rounded,
        border_color: @cyan,
        padding: 1,
        headers_color: :cyan,
        headers_effects: [:bold]
      )
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()

    ["\n", section_title_text("GLOBAL OPTIONS", @cyan), table_text, "\n"]
  end

  defp section_title_text(title, color) do
    separator =
      Separator.render(title, char: "─", width: 60, color: color)
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()

    [separator, "\n"]
  end

  defp fg_color({r, g, b}), do: "\e[38;2;#{r};#{g};#{b}m"

  defp format_option(name, type) do
    "--#{name}" <> format_type(type)
  end

  defp format_type(nil), do: ""
  defp format_type(:boolean), do: ""
  defp format_type(:flag), do: ""
  defp format_type(:integer), do: " N"
  defp format_type(:float), do: " N"
  defp format_type(:string), do: " STR"
  defp format_type(:keep), do: " ..."
  defp format_type(type) when is_atom(type), do: " #{type}"
  defp format_type(_), do: ""

  defp format_default(nil), do: "—"
  defp format_default(false), do: "false"
  defp format_default(true), do: "true"
  defp format_default(""), do: "\"\""
  defp format_default(v) when is_binary(v), do: v
  defp format_default(v) when is_atom(v), do: to_string(v)
  defp format_default(v) when is_integer(v), do: Integer.to_string(v)
  defp format_default(v) when is_float(v), do: Float.to_string(v)
  defp format_default(v), do: inspect(v)
end
