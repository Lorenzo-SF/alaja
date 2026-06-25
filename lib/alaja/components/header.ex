defmodule Alaja.Components.Header do
  @moduledoc """
  Static header component for terminal output.

  Renders a centered title with optional subtitle and decorative lines.

  ## Usage

      iex> Alaja.Components.Header.print("My App", subtitle: "v1.0.0")
      iex> Alaja.Components.Header.render("My App", size: :large)

  ## Cell engine

  As of v0.3.0, `render/2` returns an `Alaja.Buffer.t/0` (height 3 or 4
  depending on subtitle presence).
  """

  @type size :: :small | :medium | :large
  @type color :: {0..255, 0..255, 0..255} | nil

  alias Alaja.{Buffer, Cell}

  @default_color {0, 180, 216}
  @default_subtitle_color {128, 128, 128}

  @doc """
  Prints a header directly to stdout.
  """
  @spec print(String.t(), keyword()) :: :ok
  def print(title, opts \\ []) do
    title
    |> render(opts)
    |> Buffer.to_iodata()
    |> IO.write()

    IO.puts("")
  end

  @doc """
  Renders a header to an `Alaja.Buffer.t/0`.
  """
  @spec render(String.t(), keyword()) :: Buffer.t()
  def render(title, opts \\ []) do
    subtitle = Keyword.get(opts, :subtitle)
    size = Keyword.get(opts, :size, :medium)
    fg = Keyword.get(opts, :color) || @default_color
    subtitle_fg = Keyword.get(opts, :subtitle_color) || @default_subtitle_color
    width = Keyword.get(opts, :width, 80)

    {top_char, bottom_char, _padding} = size_chars(size)
    height = if subtitle, do: 4, else: 3
    buffer = Buffer.new(width, height)

    buffer =
      buffer
      |> fill_row(0, top_char, fg)
      |> write_centered(1, title, fg, width)
      |> fill_row(2, bottom_char, fg)

    if subtitle do
      write_centered(buffer, 3, subtitle, subtitle_fg, width)
    else
      buffer
    end
  end

  defp fill_row(buffer, y, char, fg) do
    Enum.reduce(0..(buffer.width - 1), buffer, fn x, buf ->
      Buffer.update_cell(buf, x, y, Cell.new(char, fg))
    end)
  end

  defp write_centered(buffer, y, string, fg, width) do
    str_len = String.length(string)
    x = div(width - str_len, 2)
    write_string(buffer, x, y, string, fg)
  end

  defp write_string(buffer, x, y, string, fg) do
    string
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {char, idx}, buf ->
      target_x = x + idx
      if target_x < buffer.width and target_x >= 0 do
        Buffer.update_cell(buf, target_x, y, Cell.new(char, fg))
      else
        buf
      end
    end)
  end

  @spec size_chars(size()) :: {String.t(), String.t(), non_neg_integer()}
  defp size_chars(:small), do: {"─", "─", 0}
  defp size_chars(:medium), do: {"═", "─", 0}
  defp size_chars(:large), do: {"█", "═", 0}
end