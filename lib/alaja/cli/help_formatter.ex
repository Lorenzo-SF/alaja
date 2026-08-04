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
      * `:globals` — optional boolean (default `true`). If `false`, the
        global options section is omitted.
  """

  alias Alaja.Components.{Header, Separator, Table}

  @doc "Renders the help keyword list to stdout."
  @spec render(keyword()) :: :ok
  def render(help_data) do
    title = Keyword.get(help_data, :title, "Alaja")
    subtitle = Keyword.get(help_data, :subtitle)
    usage = Keyword.get(help_data, :usage)
    description = Keyword.get(help_data, :description)
    options = Keyword.get(help_data, :options, [])
    show_globals = Keyword.get(help_data, :globals, true)

    Header.print(title, subtitle: subtitle, size: :small)

    if usage do
      IO.puts("")
      Separator.print("USAGE", char: "─", width: 60, color: {0, 180, 216})
      IO.puts("  " <> usage)
    end

    if description do
      IO.puts("")
      IO.puts(description)
    end

    if options != [] do
      IO.puts("")
      Separator.print("OPTIONS", char: "─", width: 60, color: {0, 180, 216})

      rows =
        Enum.map(options, fn {name, type, default, desc} ->
          opt_str = format_option(name, type)
          default_str = format_default(default) || ""
          desc_str = desc || ""
          [opt_str, default_str, desc_str]
        end)

      Table.print(
        headers: ["Option", "Default", "Description"],
        rows: rows,
        table_border: :none,
        padding: 0,
        headers_color: :cyan,
        headers_effects: [:bold]
      )
    end

    if show_globals do
      IO.puts("")
      render_globals()
    end

    :ok
  end

  @doc "Render the global options block."
  @spec render_globals() :: :ok
  def render_globals do
    Separator.print("GLOBAL OPTIONS", char: "─", width: 60, color: {0, 180, 216})
    IO.puts("")

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

    Table.print(
      headers: ["Option", "Description"],
      rows: rows,
      table_border: :none,
      padding: 0,
      headers_color: :cyan,
      headers_effects: [:bold]
    )

    :ok
  end

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
