defmodule Alaja.TableSgrRoundTripTest do
  @moduledoc """
  A table's rendered iodata is re-parsed into `Alaja.Cell` structs before
  printing, so every ANSI colour Alaja emits has to survive that round
  trip.

  The parser split the SGR parameter string on *every* `;`, which shredded
  the extended colour forms. `38;2;255;202;0` became
  `["38", "2", "255", "202", "0"]`, so:

    * the `2` was read as SGR 2 — **dim**,
    * the trailing `0` was read as SGR 0 — **foreground reset to nil**,
    * the `38` matched nothing.

  Every 24-bit colour therefore came back as `fg: nil, effects: [:dim]`:
  the border rendered grey, `--row-N-color` made row N look dim, and any
  colour whose channels happened to contain a `2` picked up the same
  phantom effect while its foreground was wiped.
  """
  use ExUnit.Case, async: true

  alias Alaja.Components.Table.Renderer

  @doc false
  defp cell_for(sgr) do
    # "X" sets the baseline; the SGR under test applies to "Y", which is
    # the cell we care about.
    Renderer.iodata_to_buffer(["X\e[#{sgr}mY\e[0m"]).cells
    |> Tuple.to_list()
    |> Enum.find(&(&1.char == "Y"))
  end

  describe "24-bit foreground survives the round trip" do
    test "keeps the colour" do
      cell = cell_for("38;2;255;202;0")
      assert cell.fg == {255, 202, 0}
    end

    test "does not invent a dim effect from the '2' in '38;2;…'" do
      cell = cell_for("38;2;255;202;0")
      assert :dim not in cell.effects
    end

    test "does not wipe the foreground with the trailing 0" do
      cell = cell_for("38;2;255;202;0")
      assert cell.fg != nil
    end

    test "works for a colour with a 2 in every channel" do
      cell = cell_for("38;2;2;2;2")
      assert cell.fg == {2, 2, 2}
      assert :dim not in cell.effects
    end
  end

  describe "xterm-256 survives the round trip" do
    test "maps through the palette for the indices it knows" do
      # `Alaja.ANSI.standard_colors/0` only carries the 16 base ANSI
      # colours, so that is the range this parser can resolve. Indices
      # above 15 (the 6x6x6 cube) are a pre-existing gap, unrelated to
      # the splitting bug.
      cell = cell_for("38;5;3")
      assert cell.fg == Map.fetch!(Alaja.ANSI.standard_colors(), 3)
      assert :dim not in cell.effects
    end

    test "does not turn the '5' into a blink" do
      cell = cell_for("38;5;3")
      refute :blink in cell.effects
    end

    test "survives a trailing effect" do
      # A bare SGR 0 after the colour would legitimately reset it, so
      # this uses a non-zero parameter to prove the 5 is not misread.
      cell = cell_for("38;5;3;1")
      assert cell.fg == Map.fetch!(Alaja.ANSI.standard_colors(), 3)
      assert :bold in cell.effects
      refute :blink in cell.effects
    end
  end

  describe "the effects that were always meant to work still do" do
    test "bold" do
      cell = cell_for("1")
      assert :bold in cell.effects
    end

    test "dim" do
      cell = cell_for("2")
      assert :dim in cell.effects
    end

    test "bold off" do
      cell = cell_for("1;2;22")
      refute :bold in cell.effects
      refute :dim in cell.effects
    end
  end

  describe "mixed colour and effects" do
    test "a colour followed by an effect" do
      cell = cell_for("38;2;255;202;0;1")
      assert cell.fg == {255, 202, 0}
      assert :bold in cell.effects
      refute :dim in cell.effects
    end

    test "an effect followed by a colour" do
      cell = cell_for("1;38;2;255;202;0")
      assert cell.fg == {255, 202, 0}
      assert :bold in cell.effects
    end
  end
end
