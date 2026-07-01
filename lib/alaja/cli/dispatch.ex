defmodule Alaja.CLI.Dispatch do
  @moduledoc """
  Dispatch helpers used by `Alaja.CLI` command handlers.

  Each handler receives a parsed `opts` map. The DSL injects `:_args`
  with the raw positional arguments so legacy modules that do their
  own `OptionParser` parsing can keep working unchanged.
  """

  alias Alaja.CLI.Commands.Show.Message

  alias Alaja.CLI.Commands.{
    Action,
    Color,
    Config
  }

  alias Alaja.CLI.Commands.Show.{
    Animate,
    AnimatedBar,
    Ask,
    Bar,
    Breadcrumbs,
    Gradient,
    Header,
    Image,
    Json,
    List,
    Menu,
    Multibar,
    Pulsar,
    Separator,
    Table,
    YesNo
  }

  @doc false
  def message(opts), do: Message.run(opts._args)
  def success(opts), do: Message.run_typed("success", opts._args)
  def error(opts), do: Message.run_typed("error", opts._args)
  def warning(opts), do: Message.run_typed("warning", opts._args)
  def info(opts), do: Message.run_typed("info", opts._args)
  def debug(opts), do: Message.run_typed("debug", opts._args)
  def notice(opts), do: Message.run_typed("notice", opts._args)
  def critical(opts), do: Message.run_typed("critical", opts._args)
  def alert(opts), do: Message.run_typed("alert", opts._args)
  def emergency(opts), do: Message.run_typed("emergency", opts._args)
  def happy(opts), do: Message.run_typed("happy", opts._args)
  def sad(opts), do: Message.run_typed("sad", opts._args)
  def header(opts), do: Header.run(opts._args)
  def separator(opts), do: Separator.run(opts._args)
  def gradient(opts), do: Gradient.run(opts._args)
  def table(opts), do: Table.run(opts._args)
  def json(opts), do: Json.run(opts._args)
  def bar(opts), do: Bar.run(opts._args)
  def animated_bar(opts), do: AnimatedBar.run(opts._args)
  def multibar(opts), do: Multibar.run(opts._args)
  def breadcrumbs(opts), do: Breadcrumbs.run(opts._args)
  def animate(opts), do: Animate.run(opts._args)
  def pulsar(opts), do: Pulsar.run(opts._args)
  def image(opts), do: Image.run(opts._args)
  def list(opts), do: List.run(opts._args)
  def ask(opts), do: Ask.run(opts._args)
  def menu(opts), do: Menu.run(opts._args)
  def yesno(opts), do: YesNo.run(opts._args)
  def color(opts), do: Color.run(opts._args)
  def action(opts), do: Action.run(opts._args)
  def config(opts), do: Config.run(opts._args)
end
