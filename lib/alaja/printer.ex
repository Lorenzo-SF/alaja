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
  @spec print_raw(iodata()) :: :ok | String.t()
  def print_raw(data), do: print_raw(data, [])

  @doc """
  Prints raw iodata or a string with global formatting options.

  Accepts the same options as `print/2` (`:raw`, `:x`, `:y`,
  `:verbose`). Also supports box wrapping via `:box`, `:box_title`,
  `:box_border`, `:box_color`, and alignment via `:align`.
  """
  @spec print_raw(iodata(), keyword()) :: :ok | String.t()
  def print_raw(data, opts) do
    text = IO.iodata_to_binary(data)
    verbose = Keyword.get(opts, :verbose, false)

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
    if Keyword.get(opts, :box, false) do
      box_opts =
        []
        |> maybe_add(:title, Keyword.get(opts, :box_title))
        |> maybe_add(:border, Keyword.get(opts, :box_border))
        |> maybe_add(:border_color, Keyword.get(opts, :box_color))

      Box.render(text, box_opts) |> IO.iodata_to_binary()
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
end
