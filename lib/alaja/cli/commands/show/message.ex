# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Alaja.CLI.Commands.Show.Message do
  @moduledoc """
  `alaja message|success|error|warning|info|...` — Display formatted messages.

  Handles both typed messages (success, error, etc.) and the generic
  `message` subcommand with full chunk styling.
  """

  alias Alaja.CLI.Color
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.CLI.Parser
  alias Alaja.Components.Box
  alias Alaja.Printer
  alias Alaja.Structures.{ChunkText, MessageInfo}

  @help_data [
    title: "Alaja Message",
    subtitle: "Display formatted text with full styling",
    usage:
      "alaja message <text> [--text T] [--color C] [--bg-color C] [--bold] [--italic] [--underline] [--dim] [--blink] [--reverse] [--hidden] [--strikethrough] [--padding N] [--addline C] [--chunk K=V]...",
    description: """
    Renders a styled message. Pass plain text as a positional argument,
    or use `--text` plus styling switches. Use `--chunk key=value` to
    emit multiple styled chunks with their own colors and effects.
    """,
    options: [
      {:text, :string, nil, "Message text (or pass positional text)"},
      {:color, :string, nil, "Foreground color"},
      {:bg_color, :string, nil, "Background color"},
      {:bold, :boolean, false, "Bold"},
      {:italic, :boolean, false, "Italic"},
      {:underline, :boolean, false, "Underline"},
      {:dim, :boolean, false, "Dim"},
      {:blink, :boolean, false, "Blink"},
      {:reverse, :boolean, false, "Reverse video"},
      {:hidden, :boolean, false, "Hidden"},
      {:strikethrough, :boolean, false, "Strikethrough"},
      {:padding, :integer, nil, "Padding around the message"},
      {:addline, :string, nil, "Char to insert between chunks (eg space, comma)"},
      {:chunk, :keep, nil, "key=value for a styled chunk (use multiple times)"},
      {:align, :string, nil, "Override alignment (else uses --align global)"}
    ],
    examples: [
      {"Plain text", "alaja message \"Hello world\""},
      {"Colour + bold", "alaja message \"Deploy\" --color cyan --bold"},
      {"Background colour", "alaja message \"Production\" --bg-color red --color white"},
      {"Multiple effects", "alaja message \"Breaking change\" --bold --underline --blink"},
      {"Chunked styling",
       "alaja message --chunk \"Deploy|color:green|bold:true\" --chunk \"started|color:cyan\""},
      {"Inside a box",
       "alaja warning \"Server down\" --box --box-title \"ALERT\" --box-color red"},
      {"Aligned right", "alaja success \"Done\" --align right"},
      {"Padded for breathing room", "alaja info \"Waiting...\" --padding 2"}
    ]
  ]

  @message_types ~w(success error warning info debug notice critical alert emergency happy sad)

  @doc """
  Runs the message command.
  """
  @spec run([String.t()]) :: :ok
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    if global.help do
      help()
    else
      handle_message(rest, global, nil)
    end
  end

  @doc """
  Runs a typed message (success, error, etc.). Called by the show dispatcher.
  """
  @spec run_typed(String.t(), [String.t()]) :: :ok
  def run_typed(type, args) do
    {global, rest} = GlobalOpts.parse(args)

    if global.help do
      help()
    else
      handle_message(rest, global, type)
    end
  end

  defp handle_message([], global, nil), do: help(global)

  defp handle_message(rest, global, nil) do
    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          text: :string,
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
          chunk: :keep
        ]
      )

    chunk_args = Keyword.get_values(opts, :chunk)

    if chunk_args != [] do
      build_multi_chunk(chunk_args, opts, global)
    else
      build_single_chunk(opts, positional, global)
    end
  end

  defp handle_message(rest, global, type) when type in @message_types do
    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          align: :string
        ]
      )

    text = Enum.join(positional, " ")

    if text == "" do
      IO.puts(:stderr, "Usage: alaja #{type} <text>")
    else
      align =
        case Keyword.get(opts, :align) do
          nil -> global.align
          val -> Parser.parse_align(val)
        end

      print_typed(type, text, align)
    end
  end

  defp print_typed(type, text, align) do
    func = typed_func(type)
    opts = [align: align]
    func.(text, opts)
  end

  defp typed_func("success"), do: &Printer.Basics.print_success/2
  defp typed_func("error"), do: &Printer.Basics.print_error/2
  defp typed_func("warning"), do: &Printer.Basics.print_warning/2
  defp typed_func("info"), do: &Printer.Basics.print_info/2
  defp typed_func("debug"), do: &Printer.Basics.print_debug/2
  defp typed_func("notice"), do: &Printer.Basics.print_notice/2
  defp typed_func("critical"), do: &Printer.Basics.print_critical/2
  defp typed_func("alert"), do: &Printer.Basics.print_alert/2
  defp typed_func("emergency"), do: &Printer.Basics.print_emergency/2
  defp typed_func("happy"), do: &Printer.Basics.print_happy/2
  defp typed_func("sad"), do: &Printer.Basics.print_sad/2

  defp build_multi_chunk(chunk_args, opts, global) do
    chunks =
      chunk_args
      |> Enum.map(&parse_chunk/1)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(fn {:ok, c} -> c end)

    if chunks == [] do
      help()
    else
      # Use local align if specified, otherwise fall back to global align
      align =
        case Keyword.get(opts, :align) do
          nil -> global.align
          val -> parse_align(val)
        end

      padding = Keyword.get(opts, :padding, 0)
      addline = parse_addline(Keyword.get(opts, :addline))

      msg = MessageInfo.new(chunks, align: align, padding: padding, add_line: addline)
      output(msg, global)
    end
  end

  defp build_single_chunk(opts, positional, global) do
    text = Keyword.get(opts, :text) || Enum.join(positional, " ")

    if text == "" do
      help()
    else
      effects = build_effects(opts)
      color = Color.parse_or_nil(Keyword.get(opts, :color))
      bg_color = Color.parse_or_nil(Keyword.get(opts, :bg_color))

      chunk_opts =
        []
        |> maybe_add(:color, color)
        |> maybe_add(:bg_color, bg_color)
        |> maybe_add(:effects, effects)

      chunk = ChunkText.new(text, chunk_opts)

      align =
        case Keyword.get(opts, :align) do
          nil -> global.align
          val -> parse_align(val)
        end

      padding = Keyword.get(opts, :padding, 0)
      addline = parse_addline(Keyword.get(opts, :addline))

      msg = MessageInfo.new([chunk], align: align, padding: padding, add_line: addline)
      output(msg, global)
    end
  end

  defp parse_chunk(chunk_str) do
    parts = String.split(chunk_str, "|")

    case parts do
      [text_only] ->
        {:ok, ChunkText.new(text_only)}

      [text | style_parts] when text != "" ->
        opts = parse_chunk_styles(style_parts)
        {:ok, ChunkText.new(text, opts)}

      _ ->
        {:error, :invalid}
    end
  rescue
    _ -> {:error, :invalid}
  end

  defp parse_chunk_styles(style_parts) do
    pairs =
      style_parts
      |> Enum.map(&String.split(&1, ":", parts: 2))
      |> Enum.filter(fn
        [_k, v] -> v != nil and v != ""
        _ -> false
      end)

    # Gather all effect flags first, then build the final opts list.
    effect_keys = ~w(bold italic underline dim blink reverse hidden strikethrough)

    effects =
      pairs
      |> Enum.filter(fn [k, v] -> k in effect_keys and v == "true" end)
      |> Enum.map(fn [k, _] -> String.to_existing_atom(k) end)

    base_opts =
      pairs
      |> Enum.reject(fn [k, _] -> k in effect_keys end)
      |> Enum.flat_map(fn
        ["color", v] -> [{:color, Color.parse_or_nil(v)}]
        ["bg", v] -> [{:bg_color, Color.parse_or_nil(v)}]
        ["bg_color", v] -> [{:bg_color, Color.parse_or_nil(v)}]
        _ -> []
      end)

    if effects == [] do
      base_opts
    else
      [{:effects, effects} | base_opts]
    end
  end

  defp build_effects(opts) do
    []
    |> maybe_add_effect(opts, :bold, :bold)
    |> maybe_add_effect(opts, :italic, :italic)
    |> maybe_add_effect(opts, :underline, :underline)
    |> maybe_add_effect(opts, :dim, :dim)
    |> maybe_add_effect(opts, :blink, :blink)
    |> maybe_add_effect(opts, :reverse, :reverse)
    |> maybe_add_effect(opts, :hidden, :hidden)
    |> maybe_add_effect(opts, :strikethrough, :strikethrough)
  end

  defp maybe_add_effect(list, opts, key, effect) do
    if Keyword.get(opts, key, false), do: list ++ [effect], else: list
  end

  # parse_color/1 delegates to Alaja.CLI.Color.parse_or_nil/1

  defp parse_align(nil), do: :left
  defp parse_align("left"), do: :left
  defp parse_align("center"), do: :center
  defp parse_align("right"), do: :right
  defp parse_align(a) when is_atom(a), do: a
  defp parse_align(_), do: :left

  defp parse_addline(nil), do: :none
  defp parse_addline("before"), do: :before
  defp parse_addline("after"), do: :after
  defp parse_addline("both"), do: :both
  defp parse_addline(_), do: :none

  defp output(msg, global) do
    if global.box do
      # Box rendering produces iodata, use print_raw to handle it
      wrapped = wrap_with_box(msg, global)
      opts = global_opts_to_printer(global)
      Printer.print_raw(wrapped, opts)
    else
      opts = global_opts_to_printer(global)
      Printer.print(msg, opts)
    end
  end

  defp wrap_with_box(%MessageInfo{} = msg, %{box: true} = global) do
    # Render the MessageInfo to a Buffer (Cell engine) and hand it to Box.
    # This keeps width measurements accurate regardless of ANSI codes.
    inner = Alaja.Components.Message.render(msg)
    Box.render(inner, box_opts(global))
  end

  defp wrap_with_box(msg, _global), do: msg

  defp box_opts(global) do
    []
    |> maybe_add(:title, global.box_title)
    |> maybe_add(:border, global.box_border)
    |> maybe_add(:border_color, global.box_color)
  end

  defp global_opts_to_printer(global) do
    [
      raw: global.raw,
      pos_x: global.pos_x,
      pos_y: global.pos_y,
      verbose: global.verbose,
      align: global.align,
      bg_color: global.bg_color,
      no_color: global.no_color,
      color: global.color
    ]
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)

  @doc """
  Prints help for the message command.
  """
  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)
end
