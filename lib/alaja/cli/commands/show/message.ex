# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Alaja.CLI.Commands.Show.Message do
  @moduledoc """
  `alaja message|success|error|warning|info|...` — Display formatted messages.

  Handles both typed messages (success, error, etc.) and the generic
  `message` subcommand with full chunk styling.
  """

  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.Parser
  alias Alaja.Components.{Box, Header, Separator, Table}
  alias Alaja.Printer
  alias Alaja.Structures.{ChunkText, MessageInfo}

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

  defp handle_message([], _global, nil), do: help()

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
      color = parse_color_opt(Keyword.get(opts, :color))
      bg_color = parse_color_opt(Keyword.get(opts, :bg_color))

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
        ["color", v] -> [{:color, parse_color(v)}]
        ["bg", v] -> [{:bg_color, parse_color(v)}]
        ["bg_color", v] -> [{:bg_color, parse_color(v)}]
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

  defp parse_color(nil), do: nil
  defp parse_color(s), do: Parser.parse_color_opt(s)

  defp parse_color_opt(nil), do: nil
  defp parse_color_opt(str), do: Parser.parse_color_opt(str)

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
    rendered = msg.chunks |> Enum.map_join("", &ChunkText.render/1)
    Box.render(rendered, box_opts(global))
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
      align: global.align
    ]
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)

  @doc """
  Prints help for the message command.
  """
  @spec help() :: :ok
  def help do
    Header.print("Alaja Message",
      subtitle: "Display formatted text with full styling",
      size: :small
    )

    IO.puts("")

    Separator.print("DESCRIPTION", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  Display a formatted message with customizable colors, text effects,")
    IO.puts("  alignment, padding, and optional box wrapping. Supports multi-chunk")
    IO.puts("  mode for painting a single line with multiple colors and styles.")
    IO.puts("")

    Separator.print("USAGE", char: "━", width: 50, color: {0, 180, 216})
    IO.puts("  alaja message <text> [options]")
    IO.puts("  alaja message --text <text> [options]")
    IO.puts("  alaja message --chunk \"text|key:val\" --chunk \"more|key:val\" [options]")
    IO.puts("")

    Separator.print("ARGUMENTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Argument", "Required", "Description"],
      rows: [
        ["<text>", "Yes*", "Text to display (positional, unless --text is used)"],
        ["--text TEXT", "Yes*", "Text to display (explicit alternative to positional)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("COLOR OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Description"],
      rows: [
        ["--color COLOR", "string", "Text color (hex:FF0000, rgb:255,0,0, red, theme:primary)"],
        ["--bg-color COLOR", "string", "Background color (same format as --color)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("TEXT EFFECTS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Description"],
      rows: [
        ["--bold", "boolean", "Bold text"],
        ["--italic", "boolean", "Italic text"],
        ["--underline", "boolean", "Underlined text"],
        ["--dim", "boolean", "Dim/faint text"],
        ["--blink", "boolean", "Blinking text"],
        ["--reverse", "boolean", "Reversed foreground/background colors"],
        ["--hidden", "boolean", "Hidden text"],
        ["--strikethrough", "boolean", "Strikethrough text"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("FORMATTING OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--align TYPE", "string", "left, center, right", "left", "Text alignment"],
        ["--padding N", "integer", "0+", "0", "Padding spaces around text"],
        [
          "--addline WHEN",
          "string",
          "before, after, both, none",
          "none",
          "Add blank lines around output"
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("MULTI-CHUNK MODE", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Description"],
      rows: [
        [
          "--chunk SPEC",
          "Define a text chunk with inline styles. Format: \"text|key:value|key:value\". Keys: color, bg/bg_color, bold, italic, underline, dim, blink, reverse, hidden, strikethrough. Repeatable."
        ]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("GLOBAL OPTIONS", char: "━", width: 50, color: {0, 180, 216})

    Table.print(
      headers: ["Option", "Type", "Values", "Default", "Description"],
      rows: [
        ["--raw", "boolean", "", "false", "Print at raw coordinates (requires --pos-x, --pos-y)"],
        ["--pos-x N", "integer", "0+", "0", "X coordinate (with --raw)"],
        ["--pos-y N", "integer", "0+", "0", "Y coordinate (with --raw)"],
        ["--verbose", "boolean", "", "false", "Return raw ANSI string instead of printing"],
        ["--box", "boolean", "", "false", "Wrap output in a bordered box"],
        ["--box-title TEXT", "string", "", "", "Title for the box (requires --box)"],
        [
          "--box-border TYPE",
          "string",
          "rounded, single, double, bold, none",
          "rounded",
          "Border style (requires --box)"
        ],
        ["--box-color COLOR", "string", "Any color format", "", "Border color (requires --box)"]
      ],
      table_border: :none,
      padding: 1
    )

    IO.puts("")

    Separator.print("EXAMPLES", char: "━", width: 50, color: {0, 180, 216})

    IO.puts(
      "# Basic positional text\n  alaja message \"Hello World\"\n\n# Explicit text with color and effect\n  alaja message \"Red bold\" --color red --bold\n\n# With background, alignment, and padding\n  alaja message \"Centered\" --color cyan --bg-color black --align center --padding 2\n\n# All formatting options\n  alaja message \"Styled\" --color \"#FF5733\" --bg-color \"#333\" --bold --underline --align right --padding 1 --addline both\n\n# Raw positioning\n  alaja message \"At coords\" --color green --raw --pos-x 10 --pos-y 5\n\n# Verbose mode (get ANSI string)\n  alaja message \"Hello\" --color blue --verbose\n\n# With box wrapper\n  alaja message \"Boxed\" --color cyan --box --box-title \"Notice\" --box-border double --box-color yellow\n\n# Multi-chunk: rainbow-like text\n  alaja message --chunk \"H|color:#FF0000|bold:true\" --chunk \"e|color:#FF7F00\" --chunk \"l|color:#FFFF00\" --chunk \"l|color:#00FF00\" --chunk \"o|color:#0000FF\"\n\n# Multi-chunk: status line\n  alaja message --chunk \"[|color:gray\" --chunk \"OK|color:green|bold:true\" --chunk \"] Deployed|color:cyan\" --align center --box --box-border rounded --box-color \"#00B4D8\""
    )

    IO.puts("")
    :ok
  end
end
