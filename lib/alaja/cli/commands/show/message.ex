defmodule Alaja.CLI.Commands.Show.Message do
  @moduledoc """
  `alaja message|success|error|warning|info|...` — Display formatted messages.

  Multiple typed commands (success, error, warning, info, debug, notice,
  critical, alert, emergency, happy, sad) all delegate to the
  generic `message` command with a `:type` flag.

  A plain typed invocation (`alaja success "Done"`, no `--text` /
  `--color` / style flags) renders through `Alaja.Printer.Basics` so it
  gets the gliphicon, the theme colour and — for alert / critical /
  emergency — the inverted background. Anything composed (`--text`,
  `--color`, `--bold`, ...) keeps the multi-chunk `Components.Message`
  path.

  The message can be composed of multiple coloured chunks by repeating
  `--text` and `--color`:

      alaja message \\
        --text "trozo 1 " --color "hex:#ffca00" \\
        --text "trozo 2 " --color "theme:quaternary" \\
        --text "trozo 3 " --color "xterm:40"
  """

  alias Alaja.CLI.Color
  alias Alaja.CLI.GlobalOpts
  alias Alaja.CLI.HelpFormatter
  alias Alaja.Components.Message, as: MessageComp
  alias Alaja.Printer
  alias Alaja.Printer.Basics
  alias Alaja.Structures.ChunkText
  alias Alaja.Structures.MessageInfo

  @typedoc """
  The message severity / category. Maps onto `Alaja.Components.Message`
  presets and ANSI styling.
  """
  @type msg_type ::
          :success
          | :error
          | :warning
          | :info
          | :debug
          | :notice
          | :critical
          | :alert
          | :emergency
          | :happy
          | :sad
          | :message

  @help_data [
    title: "Alaja Message",
    subtitle: "Display formatted messages with per-chunk colour",
    usage:
      "alaja message|success|error|warning|info|... [--text T [--color C]]... [POSITIONAL_TEXT] [OPTIONS]",
    description: """
    Renders a single- or multi-chunk message to stdout.

    The message body is built from N `--text` chunks, optionally paired
    with `--color` (same index). Chunks are concatenated horizontally
    in the order they appear on the command line. A single positional
    argument is treated as one chunk with the type's default colour.

    Colours accept `<format>:<code>` strings. Supported formats: rgb,
    argb, hex, xterm, cmyk, hsl, hsv, hwb, theme. Examples:
    `hex:#ffca00`, `theme:quaternary`, `xterm:40`, `rgb:255,0,0`.
    """,
    options: [
      {:type, :string, nil,
       "Message category: success, error, warning, info, debug, notice, critical, alert, emergency, happy, sad, message (default). Sets the default colour when no `--color` follows a `--text`."},
      {:text, :string, nil,
       "Text chunk. Repeatable. Each chunk is rendered with the next `--color` flag (or the type's default colour if no `--color` follows)."},
      {:color, :string, nil,
       "Foreground colour for the most recent `--text` chunk. Repeatable, positionally matched against `--text` chunks. Format: `<format>:<code>`."},
      {:"bg-color", :string, nil,
       "Background colour for the entire message. Format: `<format>:<code>`."},
      {:bold, :boolean, false, "Apply bold"},
      {:italic, :boolean, false, "Apply italic"},
      {:underline, :boolean, false, "Apply underline"},
      {:dim, :boolean, false, "Apply dim"},
      {:blink, :boolean, false, "Apply blink"},
      {:reverse, :boolean, false, "Apply reverse (swap fg/bg)"},
      {:hidden, :boolean, false, "Apply hidden"},
      {:strikethrough, :boolean, false, "Apply strikethrough"},
      {:padding, :integer, 0, "Extra blank lines printed above the message"},
      {:addline, :string, nil, "Extra line printed below the message in the same colour"}
    ],
    examples: [
      {"Simple typed message", "alaja success \"Deploy completed\""},
      {"Error with background", "alaja error \"Build failed\" --bg-color red"},
      {"Bold warning", "alaja warning \"Disk 92% full\" --bold"},
      {"Multi-colour composite",
       "alaja message --text \"trozo 1 \" --color \"hex:#ffca00\" --text \"trozo 2 \" --color \"theme:quaternary\" --text \"trozo 3 \" --color \"xterm:40\""},
      {"Multi-colour with theme types",
       "alaja success --text \"Build: \" --color theme:primary --text \"PASS\""}
    ]
  ]

  @doc "Runs the message command. Parses args and dispatches to `do_run/3` or `help/1`."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    # Single strict parse. The flags that need to repeat (`text`,
    # `color`) use `:keep` so all occurrences survive in the keyword
    # list. `:keep` keeps the raw string value the user supplied,
    # which is exactly what we want — we coerce colour values
    # downstream in `Color.parse_or_nil/1`.
    {opts, positional, _} =
      OptionParser.parse(rest,
        strict: [
          type: :string,
          text: :keep,
          color: :keep,
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
          addline: :string
        ]
      )

    text_list = Keyword.get_values(opts, :text)
    color_list = Keyword.get_values(opts, :color)

    if global.help do
      help(global)
    else
      do_run(opts, positional, text_list, color_list, global)
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

  @doc "Prints help text for the message command. Public for `Alaja.CLI.HelpCoverage` tests."
  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: HelpFormatter.render(@help_data, global)

  defp do_run(opts, positional, text_list, color_list, global) do
    type = parse_type(opts[:type] || List.first(positional))

    if plain_typed_message?(opts, text_list, color_list, type) do
      print_typed(type, List.first(positional) || "", GlobalOpts.to_printer_opts(global))
    else
      do_run_composed(opts, positional, text_list, color_list, global, type)
    end
  end

  # Plain `alaja success "msg"`: no `--text` / `--color` / style flags.
  # Goes through `Printer.Basics` (gliphicon + theme colour + inverted
  # backgrounds). Requires an explicit `--type` (i.e. came via
  # `run_typed/2` or `--type`) so that `alaja message "warning"` — where
  # "warning" is the *text*, not the category — keeps the generic path.
  defp plain_typed_message?(opts, text_list, color_list, type) do
    type != :message and not is_nil(opts[:type]) and text_list == [] and
      color_list == [] and is_nil(opts[:bg_color]) and
      (opts[:padding] || 0) == 0 and is_nil(opts[:addline]) and
      not Enum.any?(
        [:bold, :italic, :underline, :dim, :blink, :reverse, :hidden, :strikethrough],
        fn flag -> opts[flag] end
      )
  end

  # Typed command → Basics printer. A `case` with 11 branches trips
  # credo's complexity cap, so the mapping lives in a table instead.
  # `plain_typed_message?/4` already guarantees `type` is one of these.
  @typed_printers %{
    success: :print_success,
    error: :print_error,
    warning: :print_warning,
    info: :print_info,
    debug: :print_debug,
    notice: :print_notice,
    critical: :print_critical,
    alert: :print_alert,
    emergency: :print_emergency,
    happy: :print_happy,
    sad: :print_sad
  }

  defp print_typed(type, text, printer_opts) do
    apply(Basics, Map.fetch!(@typed_printers, type), [text, printer_opts])
    :ok
  end

  defp do_run_composed(opts, positional, text_list, color_list, global, type) do
    chunks = build_chunks(text_list, color_list, positional, opts, type)
    effects = build_effects(opts)

    info = %MessageInfo{
      chunks: chunks,
      align: :left,
      padding: opts[:padding] || 0,
      add_line:
        case opts[:addline] do
          nil ->
            :none

          extra ->
            color =
              case chunks do
                [%ChunkText{color: c} | _] when not is_nil(c) -> c
                _ -> type_fg(type)
              end

            %ChunkText{text: extra, color: color, effects: effects}
        end
    }

    rendered = MessageComp.render(info)
    Printer.print_raw(rendered, GlobalOpts.to_printer_opts(global))
    :ok
  end

  # Build the chunk list from repeated --text / --color plus a single
  # positional fallback. Chunks are produced in the order they appear
  # on the command line; colors are matched positionally to --text
  # chunks and overflow colors are dropped (the type default takes over).
  defp build_chunks(text_list, color_list, positional, opts, type) do
    default_color = type_fg(type)

    colors =
      color_list
      |> Enum.map(&Color.parse_or_nil/1)

    text_chunks =
      text_list
      |> Enum.with_index()
      |> Enum.map(fn {text, idx} ->
        color = Enum.at(colors, idx) || default_color
        %ChunkText{text: text, color: color, effects: build_effects(opts)}
      end)

    # Back-compat: a single positional argument becomes a single chunk
    # when no --text chunks were supplied (typical for `alaja success "Hello"`).
    positional_chunk =
      if text_chunks == [] do
        text = List.first(positional) || ""
        [%ChunkText{text: text, color: default_color, effects: build_effects(opts)}]
      else
        []
      end

    text_chunks ++ positional_chunk
  end

  defp build_effects(opts) do
    [
      maybe_effect(:bold, opts[:bold]),
      maybe_effect(:italic, opts[:italic]),
      maybe_effect(:underline, opts[:underline]),
      maybe_effect(:strikethrough, opts[:strikethrough]),
      maybe_effect(:dim, opts[:dim]),
      maybe_effect(:blink, opts[:blink]),
      maybe_effect(:reverse, opts[:reverse]),
      maybe_effect(:hidden, opts[:hidden])
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  defp maybe_effect(_, nil), do: nil
  defp maybe_effect(_, false), do: nil
  defp maybe_effect(atom, true), do: atom

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

  # Default fg for each type, mirroring the preset palette in
  # `Alaja.Components.Message` so behaviour stays consistent with the
  # legacy single-text path.
  defp type_fg(:success), do: {0xA6, 0xE3, 0xA1}
  defp type_fg(:error), do: {0xF3, 0x8B, 0xA8}
  defp type_fg(:warning), do: {0xF9, 0xE2, 0xAF}
  defp type_fg(:info), do: {0x89, 0xB4, 0xFA}
  defp type_fg(:debug), do: {0xCB, 0xA6, 0xF7}
  defp type_fg(:notice), do: {0x94, 0xE2, 0xD5}
  defp type_fg(:critical), do: {0xF3, 0x8B, 0xA8}
  defp type_fg(:alert), do: {0xF3, 0x8B, 0xA8}
  defp type_fg(:emergency), do: {0xF3, 0x8B, 0xA8}
  defp type_fg(:happy), do: {0xF5, 0xC2, 0xE7}
  defp type_fg(:sad), do: {0x94, 0xE2, 0xD5}
  defp type_fg(_), do: nil
end
