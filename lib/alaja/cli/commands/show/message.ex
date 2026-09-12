defmodule Alaja.CLI.Commands.Show.Message do
  @moduledoc """
  `alaja message|success|error|warning|info|...` — Display formatted messages.

  Multiple typed commands (success, error, warning, info, debug, notice,
  critical, alert, emergency, happy, sad) all delegate to the
  generic `message` command with a `:type` flag.
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.Message, as: MessageComp

  @typedoc """
  The message severity / category. Maps onto `Alaja.Components.Message`
  presets and ANSI styling.
  """
  @type msg_type ::
          :success | :error | :warning | :info | :debug | :notice
          | :critical | :alert | :emergency | :happy | :sad | :message

  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        strict: [
          type: :string,
          color: :string,
          bg_color: :string,
          bold: :boolean,
          italic: :boolean,
          underline: :boolean,
          dim: :boolean,
          blink: :boolean,
          reverse: :boolean,
          hidden: :boolean,
          strikethrough: :boolean,
          padding: :integer,
          addline: :string,
          text2: :string,
          text3: :string
        ]
      )

    if global.help do
      print_help()
    else
      do_run(opts, positional, global)
    end
  end

  @doc """
  Dispatches a typed message by string name (`"success"`, `"error"`, etc.).
  Used by `Alaja.CLI.Dispatch` to route the typed subcommands.
  """
  @spec run_typed(String.t(), [String.t()]) :: :ok | no_return()
  def run_typed(type, args) when is_binary(type) and is_list(args) do
    run(["--type", type | args])
  end

  defp do_run(opts, positional, _global) do
    type = parse_type(opts[:type] || List.first(positional))

    text =
      opts[:text2] ||
        opts[:text3] ||
        Enum.at(positional, 1) ||
        List.first(positional) ||
        ""

    MessageComp.render(text, type, build_style(opts))
    :ok
  end

  defp parse_type(nil), do: :message
  defp parse_type("success"), do: :success
  defp parse_type("error"), do: :error
  defp parse_type("warning"), do: :warning
  defp parse_type("info"), do: :info
  defp parse_type("debug"), do: :debug
  defp parse_type("notice"), do: :notice
  defp parse_type("critical"), do: :critical
  defp parse_type("alert"), do: :alert
  defp parse_type("emergency"), do: :emergency
  defp parse_type("happy"), do: :happy
  defp parse_type("sad"), do: :sad
  defp parse_type(_), do: :message

  defp build_style(opts) do
    %{}
    |> maybe_put(:color, opts[:color])
    |> maybe_put(:bg_color, opts[:bg_color])
    |> maybe_put(:bold, opts[:bold])
    |> maybe_put(:italic, opts[:italic])
    |> maybe_put(:underline, opts[:underline])
    |> maybe_put(:dim, opts[:dim])
    |> maybe_put(:blink, opts[:blink])
    |> maybe_put(:reverse, opts[:reverse])
    |> maybe_put(:hidden, opts[:hidden])
    |> maybe_put(:strikethrough, opts[:strikethrough])
    |> maybe_put(:padding, opts[:padding])
    |> maybe_put(:addline, opts[:addline])
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, false), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp print_help do
    IO.puts("""
    Usage:
      alaja message|success|error|warning|info|... [TEXT] [OPTIONS]

    Options:
      --type TYPE          one of success|error|warning|info|debug|notice|
                           critical|alert|emergency|happy|sad|message
      --color NAME         foreground color name or #hex
      --bg-color NAME      background color name or #hex
      --bold, --italic, --underline, --dim, --blink, --reverse, --hidden,
        --strikethrough
      --padding N          extra padding lines
      --addline TEXT       extra line to print below the message
      --text2 TEXT         convenience second text fragment
      --text3 TEXT         convenience third text fragment

    Examples:
      alaja success "Deploy completed"
      alaja error "Build failed" --bg-color red
      alaja warning "Disk 92% full" --bold
    """)
    :ok
  end
end
