defmodule Alaja.Components.AnimatedBarTest do
  use ExUnit.Case

  alias Alaja.{Buffer, Components.AnimatedBar}

  # Helper: render a Buffer (or legacy iodata) to a binary for substring assertions.
  defp to_binary(%Buffer{} = buffer), do: Buffer.to_iodata(buffer) |> IO.iodata_to_binary()
  defp to_binary(other), do: IO.iodata_to_binary(other)

  describe "render_frame/4" do
    test "returns Buffer.t() with percentage" do
      assert %Buffer{} = result = AnimatedBar.render_frame(50, 100, 0, animation: :spinner)
      str = to_binary(result)
      assert String.contains?(str, "50%")
    end

    test "returns Buffer.t() with label" do
      assert %Buffer{} =
               result = AnimatedBar.render_frame(75, 100, 0, label: "CPU", animation: :spinner)

      str = to_binary(result)
      assert String.contains?(str, "CPU")
      assert String.contains?(str, "75%")
    end

    test "handles zero max" do
      assert %Buffer{} = _result = AnimatedBar.render_frame(0, 0, 0)
    end

    test "handles various animation types" do
      for anim <- [:spinner, :kitt, :pulse, :wave, :rainbow] do
        assert %Buffer{} = result = AnimatedBar.render_frame(50, 100, 0, animation: anim),
               "animation #{anim} should return Buffer.t()"
      end
    end

    test "changes output based on position" do
      assert %Buffer{} = frame0 = AnimatedBar.render_frame(50, 100, 0, animation: :spinner)
      assert %Buffer{} = frame1 = AnimatedBar.render_frame(50, 100, 1, animation: :spinner)
      refute to_binary(frame0) == to_binary(frame1)
    end

    test "hides percentage when show_percent is false" do
      assert %Buffer{} = result = AnimatedBar.render_frame(50, 100, 0, show_percent: false)
      str = to_binary(result)
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
