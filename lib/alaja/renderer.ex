defmodule Alaja.Renderer do
  @moduledoc """
  Computes the minimal escape sequence to take a terminal from a
  `prev_frame` to a `next_frame`, and returns the result as iodata.

  ## Strategy

  The diff walks both frames row by row, column by column. For each
  row, it finds runs of consecutive changed cells and emits a single
  cursor move (CUP) followed by the characters of the run.

  When the previous frame is `nil`, every cell is treated as changed
  and the whole frame is rendered.

  CSI CUP positions the cursor as `ESC[row;colH` (1-based). The cursor
  only moves when the next changed cell is not consecutive to the
  previous one. A final `ESC[0m` reset is appended so trailing styles
  do not leak.

  ## Examples

      iex> Alaja.Renderer.diff(nil, frame)
      [[["\e[1;1H"], "Hello"], "\e[0m"]

  """

  alias Alaja.{Buffer, Cell, Frame}

  @type iodata_type :: iodata()

  @doc "Computes the diff `(prev -> next)` as iodata."
  @spec diff(Frame.t() | nil, Frame.t()) :: iodata_type()
  def diff(nil, %Frame{} = next), do: full_render(next)

  def diff(%Frame{} = prev, %Frame{} = next) do
    prev_buf = prev.buffer
    next_buf = next.buffer

    if same_size?(prev_buf, next_buf) do
      do_diff(prev_buf, next_buf, [])
    else
      full_render(next)
    end
  end

  defp same_size?(%Buffer{width: w1, height: h1}, %Buffer{width: w2, height: h2}),
    do: w1 == w2 and h1 == h2

  # Full render: every cell changed, emit row by row.
  defp full_render(%Frame{buffer: buf}) do
    parts =
      0..(buf.height - 1)
      |> Enum.flat_map(fn y ->
        chars = row_chars(buf, y, 0, buf.width, [])
        cup = ["\e[", Integer.to_string(y + 1), ";1H"]
        [cup, chars]
      end)

    [parts, "\e[0m"]
  end

  # Diff: build runs of changed cells, emit a CUP+chars for each run.
  defp do_diff(prev, %Buffer{height: h} = next, acc) do
    runs =
      0..(h - 1)
      |> Enum.flat_map(fn y -> changed_runs(prev, next, y) end)

    parts =
      Enum.map(runs, fn {y, x0, chars} ->
        [["\e[", Integer.to_string(y + 1), ";", Integer.to_string(x0 + 1), "H"], chars]
      end)

    [acc, parts, "\e[0m"]
  end

  # Compute runs of changed cells in a row.
  # Returns `[{y, x_start, [chars...], length}]` (one list of runs per row).
  defp changed_runs(prev, next, y) do
    do_row(prev, next, y, 0, [])
  end

  defp do_row(_prev, next, _y, x, acc) when x >= next.width, do: Enum.reverse(acc)

  defp do_row(prev, next, y, x, acc) do
    pcell = Buffer.get(prev, x, y)
    ncell = Buffer.get(next, x, y)

    if cell_equal?(pcell, ncell) do
      do_row(prev, next, y, x + 1, acc)
    else
      # start (or continue) a run from x
      {chars, x_end} = collect_run(prev, next, y, x, [])
      do_row(prev, next, y, x_end, [{y, x, chars} | acc])
    end
  end

  defp collect_run(_prev, next, _y, x, acc) when x >= next.width, do: {Enum.reverse(acc), x}

  defp collect_run(prev, next, y, x, acc) do
    if x >= next.width do
      {Enum.reverse(acc), x}
    else
      pcell = Buffer.get(prev, x, y)
      ncell = Buffer.get(next, x, y)

      if cell_equal?(pcell, ncell) do
        {Enum.reverse(acc), x}
      else
        collect_run(prev, next, y, x + 1, [ncell.char | acc])
      end
    end
  end

  defp row_chars(_buf, _y, x, w, acc) when x >= w, do: Enum.reverse(acc)

  defp row_chars(buf, y, x, w, acc) do
    cell = Buffer.get(buf, x, y)
    row_chars(buf, y, x + 1, w, [cell.char | acc])
  end

  defp cell_equal?(
         %Cell{char: c1, fg: f1, bg: b1, effects: e1},
         %Cell{char: c2, fg: f2, bg: b2, effects: e2}
       ),
       do: c1 == c2 and f1 == f2 and b1 == b2 and e1 == e2
end
