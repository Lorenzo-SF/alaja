defmodule Alaja.Printer.RawPrinter do
  @moduledoc """
  Low-level ANSI-aware I/O primitives.

  Provides cursor positioning, line clearing, and newline-gated printing
  functions used by `Alaja.Printer` when rendering at raw coordinates or
  with `add_line` modifiers.
  """

  alias Alaja.Structures.MessageInfo

  @doc """
  Prints text at a specific terminal coordinate using ANSI cursor
  positioning, optionally adding newlines before/after.
  """
  @spec print_at_raw(String.t(), {integer(), integer()}, MessageInfo.add_line()) :: :ok
  def print_at_raw(output, {x, y}, add_line) do
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

  @doc """
  Prints text with optional newlines before/after, with no cursor
  positioning.
  """
  @spec print_with_lines(String.t(), MessageInfo.add_line()) :: :ok
  def print_with_lines(output, add_line) do
    case add_line do
      :before -> IO.puts("")
      :after -> IO.puts(output)
      :both -> IO.puts(["", output, ""])
      :none -> IO.write(output <> "\n")
    end

    :ok
  end

  @doc """
  Builds an ANSI cursor-move escape sequence.
  """
  def cursor_move(x, y), do: "\e[#{y + 1};#{x + 1}H"

  @doc """
  Prepends `\\e[K` (clear line) to each row in the output.
  """
  def prepend_clear_to_rows(output) do
    binary = IO.iodata_to_binary(output)
    binary |> String.split("\n") |> Enum.map_join("\n", &("\e[K" <> &1)) |> List.wrap()
  end
end
