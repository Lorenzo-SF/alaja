defmodule Alaja.Printer.Formatter do
  @moduledoc """
  String-level formatting utilities for terminal output.

  Provides padding and alignment operations on plain strings *after*
  ANSI escape codes have been embedded.  Alignment uses the terminal
  width to compute left/center/right positioning, counting only visible
  characters (ANSI escapes are stripped before measuring lengths).
  """

  alias Alaja.Structures.MessageInfo

  @ansi_regex ~r/\x1b\[[0-9;]*m/

  @doc """
  Applies `padding` and `alignment` from a `MessageInfo` to a rendered
  text string.
  """
  @spec apply_formatting(String.t(), MessageInfo.t()) :: String.t()
  def apply_formatting(text, %MessageInfo{align: align, padding: padding}) do
    text
    |> apply_padding(padding)
    |> apply_alignment(align)
  end

  @doc """
  Wraps text with horizontal/vertical padding.

  Accepts an integer (symmetric) or a `{top, right, bottom, left}` tuple.
  """
  @spec apply_padding(String.t(), MessageInfo.padding()) :: String.t()
  def apply_padding(text, 0), do: text

  def apply_padding(text, padding) when is_integer(padding) do
    pad = String.duplicate(" ", padding)
    pad <> text <> pad
  end

  def apply_padding(text, {top, right, bottom, left}) do
    vertical_pad = "\n" |> String.duplicate(top)
    horizontal_pad = " " |> String.duplicate(left)

    lines = String.split(text, "\n")
    padded_lines = Enum.map(lines, &(horizontal_pad <> &1 <> String.duplicate(" ", right)))

    Enum.join([vertical_pad, Enum.join(padded_lines, "\n"), String.duplicate("\n", bottom)], "")
  end

  @doc """
  Aligns text within the terminal width.

  Strips ANSI escapes before measuring visible length so that alignment
  is visually correct.
  """
  @spec apply_alignment(String.t(), MessageInfo.align()) :: String.t()
  def apply_alignment(text, :left), do: text

  def apply_alignment(text, align) do
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

  @doc false
  def get_terminal_width do
    case :io.columns() do
      {:ok, width} -> width
      _ -> 80
    end
  end
end
