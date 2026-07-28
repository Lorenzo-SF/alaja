defmodule Alaja.CLI.Commands.Show.Breadcrumbs do
  @moduledoc "`alaja breadcrumbs` — Display navigation breadcrumbs."

  @help_data [
    title: "Alaja Breadcrumbs",
    subtitle: "Display navigation breadcrumbs",
    size: :small
  ]

  alias Alaja.Buffer
  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.Breadcrumbs, as: BCComp

  alias Alaja.Printer

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
  def help, do: @help_data
end
