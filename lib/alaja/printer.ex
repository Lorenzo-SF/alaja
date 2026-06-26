defmodule Alaja.Printer do
  @moduledoc """
  Central I/O dispatcher for terminal rendering.

  Delegates message-level printing to `Alaja.Printer.Basics` and provides
  the main `print/2` function for rendering `MessageInfo` structs, plain
  strings, or raw iodata with optional ANSI cursor positioning.

  ## Usage

      Alaja.Printer.print(MessageInfo.new(["Hello"]))
      Alaja.Printer.print_success("Operation completed!")
      Alaja.Printer.print_error("Something went wrong")
      Alaja.Printer.print("Loading...", raw: true, x: 10, y: 5)
  """

  alias Alaja.Components.Box
  alias Alaja.Printer.Basics
  alias Alaja.Structures.{ChunkText, MessageInfo}
  alias Alaja.Buffer

  @ansi_regex ~r/\x1b\[[0-9;]*m/

  @doc "Prints a success message (icon: ✓). Delegates to `Basics.print_success/2`."
  defdelegate print_success(msg), to: Basics

  @doc "Prints an error message (icon: ✗). Delegates to `Basics.print_error/2`."
  defdelegate print_error(msg), to: Basics

  @doc "Prints a warning message (icon: ⚠). Delegates to `Basics.print_warning/2`."
  defdelegate print_warning(msg), to: Basics

  @doc "Prints an info message (icon: ℹ). Delegates to `Basics.print_info/2`."
  defdelegate print_info(msg), to: Basics

  @doc "Prints a debug message (icon: ⚙). Delegates to `Basics.print_debug/2`."
  defdelegate print_debug(msg), to: Basics

  @doc "Prints a notice message (icon: 📢). Delegates to `Basics.print_notice/2`."
  defdelegate print_notice(msg), to: Basics

  @doc "Prints a critical message (icon: 🔥). Delegates to `Basics.print_critical/2`."
  defdelegate print_critical(msg), to: Basics

  @doc "Prints an alert message (icon: 🔔). Delegates to `Basics.print_alert/2`."
  defdelegate print_alert(msg), to: Basics

  @doc "Prints an emergency message (icon: 🆘). Delegates to `Basics.print_emergency/2`."
  defdelegate print_emergency(msg), to: Basics

  @doc """
  Prints a message with a given severity level.

  Dispatches dynamically to the corresponding `Basics.print_*/2`
  function. Unknown levels fall back to plain white text.
  """
  @print_handlers %{
    success: &Basics.print_success/1,
    error: &Basics.print_error/1,
    warning: &Basics.print_warning/1,
    info: &Basics.print_info/1,
    debug: &Basics.print_debug/1,
    notice: &Basics.print_notice/1,
    critical: &Basics.print_critical/1,
    alert: &Basics.print_alert/1,
    emergency: &Basics.print_emergency/1
  }

  @spec print_message(atom(), String.t()) :: :ok
  def print_message(level, text) do
    case Map.get(@print_handlers, level) do
      nil -> print(text, color: :white)
      handler -> handler.(text)
    end
  end

  @doc """
  Prints a `MessageInfo`, string, list, or iodata to the terminal.

  ## Parameters

  - `text_or_msg` — `MessageInfo` struct, plain string, chunk list,
    or iodata.

  ## Options

  - `:raw` — if true, print at the given `:x`/`:y` coordinates using
    ANSI cursor positioning.
  - `:x` — X coordinate for raw mode (0-indexed).
  - `:y` — Y coordinate for raw mode (0-indexed).
  - `:"pos-x"`, `:"pos-y"` — alternative key names for coordinates.
  - `:verbose` — if true, write to stdout *and* return the rendered
    string instead of `:ok`.

  ## Examples

      iex> msg = MessageInfo.new([ChunkText.new("Hello", color: :blue)])
      iex> Alaja.Printer.print(msg)
      :ok

      iex> Alaja.Printer.print("Hello", raw: true, x: 10, y: 5)
      :ok

      iex> Alaja.Printer.print("Hello", verbose: true)
      "\\e[38;2;0;180;216mHello\\e[0m"
  """
  @spec print(MessageInfo.t() | String.t() | list() | iodata(), keyword()) :: :ok | String.t()
  def print(text_or_msg, opts \\ [])

  def print(%MessageInfo{} = message_info, opts) do
    verbose = Keyword.get(opts, :verbose, false)

    rendered =
      message_info.chunks
      |> Enum.map_join("", &ChunkText.render/1)

    output = apply_formatting(rendered, message_info)

    if verbose do
      IO.puts(inspect(output))
      output
    else
      output = apply_box(output, opts)
      x = Keyword.get(opts, :"pos-x", Keyword.get(opts, :pos_x, Keyword.get(opts, :x, 0)))
      y = Keyword.get(opts, :"pos-y", Keyword.get(opts, :pos_y, Keyword.get(opts, :y, 0)))

      raw_coords = message_info.raw_coords || if opts[:raw], do: {x, y}, else: nil

      if raw_coords do
        print_at_raw(output, raw_coords, message_info.add_line)
      else
        print_with_lines(output, message_info.add_line)
      end
    end
  end

  def print(text, opts) when is_binary(text) do
    chunks = [ChunkText.new(text, opts)]
    message_info = MessageInfo.new(chunks, opts)
    print(message_info, opts)
  end

  def print(chunks, opts) when is_list(chunks) do
    if Keyword.keyword?(chunks) do
      print_raw(chunks, opts)
    else
      message_info = MessageInfo.new(chunks, opts)
      print(message_info, opts)
    end
  end

  @doc """
  Prints raw iodata or a string directly to the terminal.

  This is a convenience function equivalent to `print_raw(data, [])`.

  ## Parameters

  - `data` — iodata or string to print

  ## Examples

      iex> Alaja.Printer.print_raw("Hello")
      :ok
  """
  @spec print_raw(iodata() | Alaja.Buffer.t()) :: :ok | String.t()
  def print_raw(data), do: print_raw(data, [])

  @doc """
  Prints raw iodata, a string, or an `Alaja.Buffer.t()` with global
  formatting options.

  Accepts the same options as `print/2` (`:raw`, `:x`, `:y`,
  `:verbose`). Also supports box wrapping via `:box`, `:box_title`,
  `:box_border`, `:box_color`, and alignment via `:align`.

  If `data` is an `Alaja.Buffer.t()`, it is rendered via
  `Buffer.to_iodata/1` first. Box wrapping requires a string/iodata;
  pass a Buffer to `Box.render/2` directly if you need a Buffer-in,
  Buffer-out pipeline.
  """
  @spec print_raw(iodata() | Alaja.Buffer.t(), keyword()) :: :ok | String.t()
  def print_raw(%Alaja.Buffer{} = buffer, opts) do
    # Apply box wrapping at the Buffer level so we preserve buffer-ness
    # end-to-end. Box.render/2 accepts a Buffer and returns a Buffer;
    # calling Box.render on iodata later would lose ANSI escape coalescing.
    boxed =
      if Keyword.get(opts, :box, false) do
        box_opts =
          []
          |> maybe_add(:title, Keyword.get(opts, :box_title))
          |> maybe_add(:border, Keyword.get(opts, :box_border))
          |> maybe_add(:border_color, Keyword.get(opts, :box_color))

        Box.render(buffer, box_opts)
      else
        buffer
      end

    # Pass _box_applied: true so the iodata clause doesn't re-apply box.
    print_raw(Buffer.to_iodata(boxed), Keyword.put(opts, :_box_applied, true))
  end

  def print_raw(data, opts) do
    text = IO.iodata_to_binary(data)
    verbose = Keyword.get(opts, :verbose, false)

    # Note: Box wrapping for Buffer input is handled in the Buffer clause
    # above. Here we only apply it when input was iodata/string.
    text = apply_box(text, opts)
    text = apply_align(text, opts)
    text = String.trim_trailing(text, "\n")

    if verbose do
      IO.puts(inspect(text))
      text
    else
      x = Keyword.get(opts, :"pos-x", Keyword.get(opts, :pos_x, Keyword.get(opts, :x, 0)))
      y = Keyword.get(opts, :"pos-y", Keyword.get(opts, :pos_y, Keyword.get(opts, :y, 0)))

      if opts[:raw] do
        print_at_raw(text, {x, y}, :none)
      else
        print_with_lines(text, :none)
      end
    end
  end

  defp apply_box(text, opts) do
    # When input was a Buffer, we already applied Box at the Buffer level
    # in the Buffer clause. Skip here to avoid double-wrapping.
  if Keyword.get(opts, :box, false) and not Keyword.get(opts, :_box_applied, false) do
      box_opts =
        []
        |> maybe_add(:title, Keyword.get(opts, :box_title))
        |> maybe_add(:border, Keyword.get(opts, :box_border))
        |> maybe_add(:border_color, Keyword.get(opts, :box_color))

      # Box.render/2 returns a Buffer. Convert it back to a binary so the
      # downstream pipeline (alignment, padding, trim) keeps operating on
      # string-typed values. ANSI coalescing is preserved by
      # Buffer.to_iodata/1.
      Box.render(text, box_opts)
      |> Buffer.to_iodata()
      |> IO.iodata_to_binary()
    else
      text
    end
  end

  defp apply_align(text, opts) do
    align = Keyword.get(opts, :align, :left)
    apply_alignment(text, align)
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)

  @spec apply_formatting(String.t(), MessageInfo.t()) :: String.t()
  defp apply_formatting(text, %MessageInfo{align: align, padding: padding}) do
    text = apply_padding(text, padding)
    apply_alignment(text, align)
  end

  @spec apply_padding(String.t(), MessageInfo.padding()) :: String.t()
  defp apply_padding(text, 0), do: text

  defp apply_padding(text, padding) when is_integer(padding) do
    pad = String.duplicate(" ", padding)
    pad <> text <> pad
  end

  defp apply_padding(text, {top, right, bottom, left}) do
    vertical_pad = "\n" |> String.duplicate(top)
    horizontal_pad = " " |> String.duplicate(left)

    lines = String.split(text, "\n")
    padded_lines = Enum.map(lines, &(horizontal_pad <> &1 <> String.duplicate(" ", right)))

    Enum.join([vertical_pad, Enum.join(padded_lines, "\n"), String.duplicate("\n", bottom)], "")
  end

  @spec apply_alignment(String.t(), MessageInfo.align()) :: String.t()
  defp apply_alignment(text, :left), do: text

  defp apply_alignment(text, align) do
    terminal_width = get_terminal_width()
    lines = String.split(text, "\n")

    max_visible =
      lines
      |> Enum.map(&(String.replace(&1, @ansi_regex, "") |> String.length()))
      |> Enum.max(fn -> 0 end)

    padding =
      case align do
        :center -> div(max(terminal_width - max_visible, 0), 2)
        :right -> max(terminal_width - max_visible, 0)
        _ -> 0
      end

    Enum.map_join(lines, "\n", &(String.duplicate(" ", padding) <> &1))
  end

  @spec print_at_raw(String.t(), {integer(), integer()}, MessageInfo.add_line()) :: :ok
  defp print_at_raw(output, {x, y}, add_line) do
    cursor_move = "\e[#{y + 1};#{x + 1}H"
    clear_line = "\e[K"

    case add_line do
      :before ->
        IO.write(cursor_move <> clear_line <> "\n" <> output)

      :after ->
        IO.write(cursor_move <> clear_line <> output <> "\n")

      :both ->
        IO.write(cursor_move <> clear_line <> "\n" <> output <> "\n")

      :none ->
        IO.write(cursor_move <> clear_line <> output)
    end

    :ok
  end

  @spec print_with_lines(String.t(), MessageInfo.add_line()) :: :ok
  defp print_with_lines(output, add_line) do
    case add_line do
      :before -> IO.puts("")
      :after -> IO.puts(output)
      :both -> IO.puts(["", output, ""])
      :none -> IO.write(output <> "\n")
    end

    :ok
  end

  @spec get_terminal_width() :: integer()
  defp get_terminal_width do
    case :io.columns() do
      {:ok, width} -> width
      _ -> 80
    end
  end

  @doc """
  Prints a `Alaja.Buffer.t()` to the terminal, optionally positioned at
  `(x, y)` via ANSI cursor escape. Unlike `print_raw/2`, this preserves
  the 2D structure of the buffer when positioning it on screen.

  ## Options

  - `:x` / `:pos_x` / `:"pos-x"` — column (default 0)
  - `:y` / `:pos_y` / `:"pos-y"` — row (default 0)
  - `:verbose` — return the rendered string instead of writing
  - `:clear_line` — when `true`, prepend `\e[K` to each row to clear
    trailing characters (default `true`)

  ## Examples

      buffer = Alaja.Buffer.new(5, 1) |> Alaja.Buffer.put(0, 0, "X", {255, 0, 0})
      Alaja.Printer.print_buffer(buffer, x: 10, y: 5)
  """
  @spec print_buffer(Alaja.Buffer.t(), keyword()) :: :ok | String.t()
  def print_buffer(%Alaja.Buffer{} = buffer, opts \\ []) do
    verbose = Keyword.get(opts, :verbose, false)

    # The buffer's offset_x/offset_y are added on top of any explicit
    # x/y option. This lets layouts compose: a Table rendered with
    # `with_offset(t, 5, 0)` and a Box next to it can both be printed
    # to the same terminal row without overwriting each other.
    x = (buffer.offset_x || 0) + Keyword.get(opts, :"pos-x", Keyword.get(opts, :pos_x, Keyword.get(opts, :x, 0)))
    y = (buffer.offset_y || 0) + Keyword.get(opts, :"pos-y", Keyword.get(opts, :pos_y, Keyword.get(opts, :y, 0)))
    clear_line = Keyword.get(opts, :clear_line, true)

    output =
      if x == 0 and y == 0 do
        Alaja.Buffer.to_iodata(buffer)
      else
        [cursor_move(x, y), Alaja.Buffer.to_iodata(buffer)]
      end

    output =
      if clear_line do
        prepend_clear_to_rows(output)
      else
        output
      end

    if verbose do
      text = IO.iodata_to_binary(output)
      IO.puts(inspect(text))
      text
    else
      IO.write(output)
      :ok
    end
  end

  defp cursor_move(x, y), do: "\e[#{y + 1};#{x + 1}H"

  defp prepend_clear_to_rows(output) do
    # Coalesce output into a binary, split on newlines, prepend \e[K to each
    binary = IO.iodata_to_binary(output)
    binary |> String.split("\n") |> Enum.map_join("\n", &("\e[K" <> &1)) |> List.wrap()
  end
end
