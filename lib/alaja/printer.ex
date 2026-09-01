defmodule Alaja.Printer do
  @moduledoc """
  Central I/O dispatcher for terminal rendering.

  Delegates message-level printing to `Alaja.Printer.Basics`, string-level
  formatting to `Alaja.Printer.Formatter`, and low-level ANSI I/O to
  `Alaja.Printer.RawPrinter`.
  """

  alias Alaja.Buffer
  alias Alaja.Components.Box
  alias Alaja.Printer.{Basics, Formatter, RawPrinter}
  alias Alaja.Structures.{ChunkText, MessageInfo}

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

  See `Alaja.Printer.Formatter` and `Alaja.Printer.RawPrinter` for the
  underlying formatting and I/O primitives.
  """
  @spec print(MessageInfo.t() | String.t() | list() | iodata(), keyword()) :: :ok | String.t()
  def print(text_or_msg, opts \\ [])

  def print(%MessageInfo{} = message_info, opts) do
    verbose = Keyword.get(opts, :verbose, false)

    rendered =
      message_info.chunks
      |> Enum.map_join("", &ChunkText.render/1)

    output = Formatter.apply_formatting(rendered, message_info)

    if verbose do
      IO.puts(inspect(output))
      output
    else
      output =
        output
        |> apply_box(opts)
        |> apply_bg(opts)

      x = Keyword.get(opts, :"pos-x", Keyword.get(opts, :pos_x, Keyword.get(opts, :x, 0)))
      y = Keyword.get(opts, :"pos-y", Keyword.get(opts, :pos_y, Keyword.get(opts, :y, 0)))

      raw_coords = message_info.raw_coords || if opts[:raw], do: {x, y}, else: nil

      if raw_coords do
        RawPrinter.print_at_raw(output, raw_coords, message_info.add_line)
      else
        RawPrinter.print_with_lines(output, message_info.add_line)
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
  """
  @spec print_raw(iodata() | Alaja.Buffer.t()) :: :ok | String.t()
  def print_raw(data), do: print_raw(data, [])

  @doc """
  Prints raw iodata, a string, or an `Alaja.Buffer.t()` with global
  formatting options.
  """
  @spec print_raw(iodata() | Alaja.Buffer.t(), keyword()) :: :ok | String.t()
  def print_raw(%Alaja.Buffer{} = buffer, opts) do
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

    print_raw(Buffer.to_iodata(boxed), Keyword.put(opts, :_box_applied, true))
  end

  def print_raw(data, opts) do
    text = IO.iodata_to_binary(data)
    verbose = Keyword.get(opts, :verbose, false)

    text =
      text
      |> format_raw(opts)
      |> String.trim_trailing("\n")
      |> apply_bg(opts)

    if verbose do
      IO.puts(inspect(text))
      text
    else
      x = Keyword.get(opts, :"pos-x", Keyword.get(opts, :pos_x, Keyword.get(opts, :x, 0)))
      y = Keyword.get(opts, :"pos-y", Keyword.get(opts, :pos_y, Keyword.get(opts, :y, 0)))

      if opts[:raw] do
        RawPrinter.print_at_raw(text, {x, y}, :none)
      else
        RawPrinter.print_with_lines(text, :none)
      end
    end
  end

  @doc """
  Applies box and alignment formatting to raw text without writing it.

  Shared by `print_raw/2` and the tabbed help renderer so both honour
  the global `--box`/`--box-title`/`--box-border`/`--box-color` and
  `--align` options.
  """
  @spec format_raw(String.t(), keyword()) :: String.t()
  def format_raw(text, opts) do
    text
    |> apply_box(opts)
    |> Formatter.apply_alignment(Keyword.get(opts, :align, :left))
  end

  defp apply_box(text, opts) do
    if Keyword.get(opts, :box, false) and not Keyword.get(opts, :_box_applied, false) do
      box_opts =
        []
        |> maybe_add(:title, Keyword.get(opts, :box_title))
        |> maybe_add(:border, Keyword.get(opts, :box_border))
        |> maybe_add(:border_color, Keyword.get(opts, :box_color))

      Box.render(text, box_opts)
      |> Buffer.to_iodata()
      |> IO.iodata_to_binary()
    else
      text
    end
  end

  defp maybe_add(list, _key, nil), do: list
  defp maybe_add(list, key, value), do: Keyword.put(list, key, value)

  @doc """
  Wraps text with the global `--bg-color` background, if set.
  """
  @spec apply_bg(String.t(), keyword()) :: String.t()
  def apply_bg(text, opts) do
    case Keyword.get(opts, :bg_color) do
      {r, g, b} when is_integer(r) and is_integer(g) and is_integer(b) ->
        if Keyword.get(opts, :no_color, false) do
          text
        else
          text
          |> then(&[Alaja.ANSI.bg(r, g, b), &1, Alaja.ANSI.reset_attributes()])
          |> IO.iodata_to_binary()
        end

      _ ->
        text
    end
  end

  @doc """
  Prints a `Alaja.Buffer.t()` to the terminal, optionally positioned at
  `(x, y)` via ANSI cursor escape.
  """
  @spec print_buffer(Alaja.Buffer.t(), keyword()) :: :ok | String.t()
  def print_buffer(%Alaja.Buffer{} = buffer, opts \\ []) do
    verbose = Keyword.get(opts, :verbose, false)

    x =
      (buffer.offset_x || 0) +
        Keyword.get(opts, :"pos-x", Keyword.get(opts, :pos_x, Keyword.get(opts, :x, 0)))

    y =
      (buffer.offset_y || 0) +
        Keyword.get(opts, :"pos-y", Keyword.get(opts, :pos_y, Keyword.get(opts, :y, 0)))

    clear_line = Keyword.get(opts, :clear_line, true)

    output =
      if x == 0 and y == 0 do
        Alaja.Buffer.to_iodata(buffer)
      else
        [RawPrinter.cursor_move(x, y), Alaja.Buffer.to_iodata(buffer)]
      end

    output =
      if clear_line do
        RawPrinter.prepend_clear_to_rows(output)
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
end
