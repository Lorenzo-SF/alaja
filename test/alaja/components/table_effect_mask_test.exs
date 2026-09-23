defmodule Alaja.Components.Table.EffectMaskTest do
  @moduledoc """
  Tests for the per-cell effect-mask feature
  (`--row-N-<effect> "<bool>;<bool>;..."`).

  Backed by:
    * `Alaja.Components.Table.Builder.apply_effect_mask/3`
    * `Alaja.Components.Table.Builder.get_row_opts/5`
    * `Alaja.Components.Table.Builder.extract_row_specific_opts/1`

  Run via `mix test test/alaja/components/table_effect_mask_test.exs`.
  """

  use ExUnit.Case, async: true

  alias Alaja.Components.Table.Builder

  describe "apply_effect_mask/3" do
    test "with no masks, all row effects survive per cell" do
      assert Builder.apply_effect_mask([:bold, :italic], 0, %{}) == [:bold, :italic]
      assert Builder.apply_effect_mask([:bold, :italic], 99, %{}) == [:bold, :italic]
    end

    test "mask with all-true values keeps every effect" do
      assert Builder.apply_effect_mask([:bold], 0, %{bold: [true]}) == [:bold]
      assert Builder.apply_effect_mask([:bold], 2, %{bold: [true, true, true]}) == [:bold]
    end

    test "mask with all-false values drops the effect" do
      assert Builder.apply_effect_mask([:bold], 0, %{bold: [false]}) == []
      assert Builder.apply_effect_mask([:bold, :italic], 1, %{bold: [true, false], italic: [true, false]}) == []
    end

    test "mixed mask keeps the effect only on truthy cells" do
      effects = [:bold, :italic]

      assert Builder.apply_effect_mask(effects, 0, %{bold: [true, false, true]}) == [:bold, :italic]
      assert Builder.apply_effect_mask(effects, 1, %{bold: [true, false, true]}) == [:italic]
      assert Builder.apply_effect_mask(effects, 2, %{bold: [true, false, true]}) == [:bold, :italic]
    end

    test "mask shorter than the row keeps the effect on cells beyond the mask" do
      # User opted cells 0 and 1 out; cells 2, 3, 4 keep the effect.
      assert Builder.apply_effect_mask([:bold], 0, %{bold: [false, false]}) == []
      assert Builder.apply_effect_mask([:bold], 2, %{bold: [false, false]}) == [:bold]
      assert Builder.apply_effect_mask([:bold], 99, %{bold: [false, false]}) == [:bold]
    end

    test "truthy non-boolean mask values fall back to keeping the effect" do
      # Garbage in the mask must not crash the render — defensive default.
      assert Builder.apply_effect_mask([:bold], 0, %{bold: [:garbage]}) == [:bold]
      assert Builder.apply_effect_mask([:bold], 0, %{bold: ["maybe"]}) == [:bold]
    end

    test "non-list mask (e.g. single boolean) keeps the effect" do
      # Stops a malformed CLI entry from silently dropping every effect.
      assert Builder.apply_effect_mask([:bold], 0, %{bold: true}) == [:bold]
    end
  end

  describe "get_row_opts/5 with masks" do
    test "extracts masks per row, leaves others untouched" do
      row_specific_opts = %{
        0 => [{0, :bold, [true, false, true]}],
        1 => [{1, :italic, [false, true]}, {1, :bold, [true]}]
      }

      {_, _, _, masks0} = Builder.get_row_opts(0, row_specific_opts, nil, [], :left)
      assert masks0 == %{bold: [true, false, true]}

      {_, _, _, masks1} = Builder.get_row_opts(1, row_specific_opts, nil, [], :left)
      assert masks1 == %{italic: [false, true], bold: [true]}

      {_, _, _, masks_default} = Builder.get_row_opts(99, row_specific_opts, nil, [], :left)
      assert masks_default == %{}
    end

    test "non-effect opts (color, align, effects) stay out of the masks map" do
      row_specific_opts = %{
        0 => [
          {0, :color, [{255, 0, 0}, nil]},
          {0, :align, [:left, :right]},
          {0, :effects, [:bold, :italic]},
          {0, :bold, [true, false]}
        ]
      }

      {_, _, _, masks} = Builder.get_row_opts(0, row_specific_opts, nil, [], :left)
      assert masks == %{bold: [true, false]}
    end
  end

  describe "extract_row_specific_opts/1 with new effect-name rows" do
    test "captures rows_N_<effect> as a per-cell mask" do
      opts = [
        rows_0_bold: [true, false, true],
        rows_1_italic: [false, true, false]
      ]

      grouped = Builder.extract_row_specific_opts(opts)

      assert [{0, :bold, [true, false, true]}] = grouped[0]
      assert [{1, :italic, [false, true, false]}] = grouped[1]
    end

    test "still captures legacy rows_N_color / _align / _effects" do
      opts = [
        rows_0_color: [nil, {255, 0, 0}],
        rows_1_align: [:left, :right],
        rows_2_effects: [:bold]
      ]

      grouped = Builder.extract_row_specific_opts(opts)
      assert is_list(grouped[0])
      assert is_list(grouped[1])
      assert is_list(grouped[2])
    end
  end
end
