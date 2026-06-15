defmodule Alaja.Printer.Basics do
  @moduledoc """
  Pre-styled message printing with severity icons and ANSI colours.

  Provides 12 severity-level functions — success, error, warning, info,
  debug, notice, alert, critical, emergency, happy, and sad. Each
  prefixes the message with a Unicode icon and applies colour styling
  resolved through Pote's theme system.
  """

  alias Alaja.Printer
  alias Alaja.Structures.{ChunkText, MessageInfo}

  @doc """
  Prints an informational message.

  Icon: ℹ — colour: cyan.

  Accepts printer options (see `Alaja.Printer.print/2`).
  """
  @spec print_info(String.t(), keyword()) :: :ok | String.t()
  def print_info(text, opts \\ []) do
    chunks = [ChunkText.new(" ℹ  ", color: :cyan), ChunkText.new(text)]
    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints a success message.

  Icon: ✓ — colour: success (green).
  """
  @spec print_success(String.t(), keyword()) :: :ok | String.t()
  def print_success(text, opts \\ []) do
    chunks = [ChunkText.new(" ✓  ", color: :success), ChunkText.new(text, color: :success)]
    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints an error message.

  Icon: ✗ — colour: error (red), bold.
  """
  @spec print_error(String.t(), keyword()) :: :ok | String.t()
  def print_error(text, opts \\ []) do
    chunks = [
      ChunkText.new(" ✗  ", color: :error, effects: [:bold]),
      ChunkText.new(text, color: :error)
    ]

    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints a warning message.

  Icon: ⚠ — colour: warning (yellow/orange).
  """
  @spec print_warning(String.t(), keyword()) :: :ok | String.t()
  def print_warning(text, opts \\ []) do
    chunks = [ChunkText.new(" ⚠  ", color: :warning), ChunkText.new(text, color: :warning)]
    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints an alert message (inverted warning).

  Icon: 🔔 — warning background with bold.
  """
  @spec print_alert(String.t(), keyword()) :: :ok | String.t()
  def print_alert(text, opts \\ []) do
    chunks = [
      ChunkText.new(" 🔔 ", color: :background, bg_color: :warning, effects: [:bold]),
      ChunkText.new(" " <> text, color: :warning)
    ]

    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints a critical message (inverted error).

  Icon: 🔥 — error background, bold.
  """
  @spec print_critical(String.t(), keyword()) :: :ok | String.t()
  def print_critical(text, opts \\ []) do
    chunks = [
      ChunkText.new(" 🔥 ", color: :background, bg_color: :error, effects: [:bold]),
      ChunkText.new(" " <> text, color: :error, effects: [:bold])
    ]

    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints a debug message.

  Icon: ⚙ — colour: debug (purple/magenta).
  """
  @spec print_debug(String.t(), keyword()) :: :ok | String.t()
  def print_debug(text, opts \\ []) do
    chunks = [ChunkText.new(" ⚙  ", color: :debug), ChunkText.new(text, color: :debug)]
    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints a happy/positive message.

  Icon: ✨ — colour: happy.
  """
  @spec print_happy(String.t(), keyword()) :: :ok | String.t()
  def print_happy(text, opts \\ []) do
    chunks = [ChunkText.new(" ✨ ", color: :happy), ChunkText.new(text, color: :happy)]
    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints a sad/negative message.

  Icon: ❄ — colour: sad.
  """
  @spec print_sad(String.t(), keyword()) :: :ok | String.t()
  def print_sad(text, opts \\ []) do
    chunks = [ChunkText.new(" ❄  ", color: :sad), ChunkText.new(text, color: :sad)]
    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints a notice message.

  Icon: 📢 — colour: info.
  """
  @spec print_notice(String.t(), keyword()) :: :ok | String.t()
  def print_notice(text, opts \\ []) do
    chunks = [ChunkText.new(" 📢 ", color: :info), ChunkText.new(text, color: :info)]
    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  @doc """
  Prints an emergency message.

  Icon: 🆘 — error background, bold and blinking.
  """
  @spec print_emergency(String.t(), keyword()) :: :ok | String.t()
  def print_emergency(text, opts \\ []) do
    chunks = [
      ChunkText.new(" 🆘 ", color: :background, bg_color: :error, effects: [:bold, :blink]),
      ChunkText.new(" " <> text, color: :error, effects: [:bold, :blink])
    ]

    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end
end
