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
    Theme
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
  @doc "Dispatches the `alaja success` message command."
  def success(opts), do: Message.run_typed("success", opts._args)
  @doc "Dispatches the `alaja error` message command."
  def error(opts), do: Message.run_typed("error", opts._args)
  @doc "Dispatches the `alaja warning` message command."
  def warning(opts), do: Message.run_typed("warning", opts._args)
  @doc "Dispatches the `alaja info` message command."
  def info(opts), do: Message.run_typed("info", opts._args)
  @doc "Dispatches the `alaja debug` message command."
  def debug(opts), do: Message.run_typed("debug", opts._args)
  @doc "Dispatches the `alaja notice` message command."
  def notice(opts), do: Message.run_typed("notice", opts._args)
  @doc "Dispatches the `alaja critical` message command."
  def critical(opts), do: Message.run_typed("critical", opts._args)
  @doc "Dispatches the `alaja alert` message command."
  def alert(opts), do: Message.run_typed("alert", opts._args)
  @doc "Dispatches the `alaja emergency` message command."
  def emergency(opts), do: Message.run_typed("emergency", opts._args)
  @doc "Dispatches the `alaja happy` message command."
  def happy(opts), do: Message.run_typed("happy", opts._args)
  @doc "Dispatches the `alaja sad` message command."
  def sad(opts), do: Message.run_typed("sad", opts._args)
  @doc "Dispatches the `alaja header` command."
  def header(opts), do: Header.run(opts._args)
  @doc "Dispatches the `alaja separator` command."
  def separator(opts), do: Separator.run(opts._args)
  @doc "Dispatches the `alaja gradient` command."
  def gradient(opts), do: Gradient.run(opts._args)
  @doc "Dispatches the `alaja table` command."
  def table(opts), do: Table.run(opts._args)
  @doc "Dispatches the `alaja json` command."
  def json(opts), do: Json.run(opts._args)
  @doc "Dispatches the `alaja bar` command."
  def bar(opts), do: Bar.run(opts._args)
  @doc "Dispatches the `alaja animated-bar` command."
  def animated_bar(opts), do: AnimatedBar.run(opts._args)
  @doc "Dispatches the `alaja multibar` command."
  def multibar(opts), do: Multibar.run(opts._args)
  @doc "Dispatches the `alaja breadcrumbs` command."
  def breadcrumbs(opts), do: Breadcrumbs.run(opts._args)
  @doc "Dispatches the `alaja animate` command."
  def animate(opts), do: Animate.run(opts._args)
  @doc "Dispatches the `alaja pulsar` command."
  def pulsar(opts), do: Pulsar.run(opts._args)
  @doc "Dispatches the `alaja image` command."
  def image(opts), do: Image.run(opts._args)
  @doc "Dispatches the `alaja list` command."
  def list(opts), do: List.run(opts._args)
  @doc "Dispatches the `alaja ask` command."
  def ask(opts), do: Ask.run(opts._args)
  @doc "Dispatches the `alaja menu` command."
  def menu(opts), do: Menu.run(opts._args)
  @doc "Dispatches the `alaja yesno` command."
  def yesno(opts), do: YesNo.run(opts._args)
  @doc "Dispatches the `alaja color` command."
  def color(opts), do: Color.run(opts._args)
  @doc "Dispatches the `alaja action` command."
  def action(opts), do: Action.run(opts._args)
  @doc "Dispatches the `alaja theme` command."
  def theme(opts), do: Theme.run(opts._args)

  @doc "Dispatches the deprecated `alaja config` command (prints deprecation notice and returns `:error`)."
  def config(opts), do: Alaja.CLI.Commands.Config.run(opts._args)
end
