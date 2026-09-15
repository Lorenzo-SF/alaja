defmodule Alaja.Components.PulsarTest do
  @moduledoc """
  Tests for Alaja.Components.Pulsar (general rendering, not image).
  Image-specific tests live in pulsar_image_test.exs.
  """
  use ExUnit.Case, async: true

  alias Alaja.Components.Pulsar

  describe "render_frame/3" do
    test "returns a buffer of the requested dimensions" do
      buffer = Pulsar.render_frame("hi", 0, width: 20, height: 5)
      assert buffer.width == 20
      assert buffer.height == 5
    end

    test "different frames produce different outputs (animation)" do
      b1 = Pulsar.render_frame("hi", 0, width: 20, height: 5)
      b2 = Pulsar.render_frame("hi", 5, width: 20, height: 5)
      refute render_to_string(b1) == render_to_string(b2)
    end

    test "handles empty text" do
      buffer = Pulsar.render_frame("", 0, width: 10, height: 3)
      assert buffer.width == 10
      assert buffer.height == 3
    end

    test "handles empty pulse_chars (falls back to defaults)" do
      buffer = Pulsar.render_frame("hi", 0, width: 10, height: 3, pulse_chars: [])
      assert buffer.width == 10
    end

    test "respects :direction :in" do
      b_in = Pulsar.render_frame("hi", 0, width: 10, height: 3, direction: :in)
      b_out = Pulsar.render_frame("hi", 0, width: 10, height: 3, direction: :out)
      refute render_to_string(b_in) == render_to_string(b_out)
    end
  end

  describe "render_iodata/3" do
    test "returns iodata" do
      result = Pulsar.render_iodata("hi", 0, width: 10, height: 3)
      assert is_list(result) or is_binary(result)
      # Should be convertible to binary
      assert is_binary(IO.iodata_to_binary(result))
    end
  end

  # Helper: render a buffer to string for comparison
  defp render_to_string(buffer) do
    Pulsar.render_buffer_iodata(buffer)
  end
end
