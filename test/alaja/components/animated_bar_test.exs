defmodule Alaja.Components.AnimatedBarTest do
  use ExUnit.Case

  alias Alaja.Components.AnimatedBar

  describe "render_frame/4" do
    test "returns iodata with percentage" do
      result = AnimatedBar.render_frame(50, 100, 0, animation: :spinner)
      assert is_list(result)
      str = IO.iodata_to_binary(result)
      assert String.contains?(str, "50%")
    end

    test "returns iodata with label" do
      result = AnimatedBar.render_frame(75, 100, 0, label: "CPU", animation: :spinner)
      str = IO.iodata_to_binary(result)
      assert String.contains?(str, "CPU")
      assert String.contains?(str, "75%")
    end

    test "handles zero max" do
      result = AnimatedBar.render_frame(0, 0, 0)
      assert is_list(result)
    end

    test "handles various animation types" do
      for anim <- [:spinner, :kitt, :pulse, :wave, :rainbow] do
        result = AnimatedBar.render_frame(50, 100, 0, animation: anim)
        assert is_list(result), "animation #{anim} should return iodata"
      end
    end

    test "changes output based on position" do
      frame0 = AnimatedBar.render_frame(50, 100, 0, animation: :spinner)
      frame1 = AnimatedBar.render_frame(50, 100, 1, animation: :spinner)
      refute IO.iodata_to_binary(frame0) == IO.iodata_to_binary(frame1)
    end

    test "hides percentage when show_percent is false" do
      result = AnimatedBar.render_frame(50, 100, 0, show_percent: false)
      str = IO.iodata_to_binary(result)
      refute String.contains?(str, "%")
    end
  end

  describe "run_infinite/3" do
    test "terminates after max_iterations" do
      result =
        AnimatedBar.run_infinite(50, 100,
          animation: :spinner,
          speed: 1,
          max_iterations: 3,
          verbose: true
        )

      assert result == :ok
    end
  end
end
