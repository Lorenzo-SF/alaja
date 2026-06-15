defmodule Alaja.Structures.MessageInfoTest do
  use ExUnit.Case, async: true

  alias Alaja.Structures.{ChunkText, MessageInfo}

  describe "new/1" do
    test "creates MessageInfo with empty chunks" do
      msg = MessageInfo.new([])
      assert msg.chunks == []
      assert msg.align == :left
      assert msg.padding == 0
      assert msg.add_line == :none
      assert msg.raw_coords == nil
    end

    test "creates MessageInfo with string chunks (converted to ChunkText)" do
      msg = MessageInfo.new(["Hello", " World"])
      assert length(msg.chunks) == 2
      assert Enum.all?(msg.chunks, &match?(%ChunkText{}, &1))
    end

    test "creates MessageInfo with ChunkText chunks" do
      chunk = ChunkText.new("Hello")
      msg = MessageInfo.new([chunk])
      assert msg.chunks == [chunk]
    end

    test "creates MessageInfo with mixed chunks" do
      chunk = ChunkText.new("Hello")
      msg = MessageInfo.new([chunk, " World"])
      assert length(msg.chunks) == 2
    end

    test "creates MessageInfo with single string" do
      msg = MessageInfo.new(["Hello"])
      assert length(msg.chunks) == 1
    end
  end

  describe "new/2 with options" do
    test "accepts :align option" do
      msg = MessageInfo.new(["Hello"], align: :center)
      assert msg.align == :center
    end

    test "accepts :padding option as integer" do
      msg = MessageInfo.new(["Hello"], padding: 5)
      assert msg.padding == 5
    end

    test "accepts :padding option as tuple" do
      msg = MessageInfo.new(["Hello"], padding: {1, 2, 3, 4})
      assert msg.padding == {1, 2, 3, 4}
    end

    test "accepts :add_line option" do
      for add_line <- [:before, :after, :both, :none] do
        msg = MessageInfo.new(["Hello"], add_line: add_line)
        assert msg.add_line == add_line
      end
    end

    test "accepts :raw_coords option" do
      msg = MessageInfo.new(["Hello"], raw_coords: {10, 5})
      assert msg.raw_coords == {10, 5}
    end

    test "accepts all options together" do
      msg =
        MessageInfo.new(
          ["Hello"],
          align: :right,
          padding: 3,
          add_line: :both,
          raw_coords: {0, 0}
        )

      assert msg.align == :right
      assert msg.padding == 3
      assert msg.add_line == :both
      assert msg.raw_coords == {0, 0}
    end
  end

  describe "invalid option handling" do
    test "invalid align falls back to :left" do
      msg = MessageInfo.new(["Hello"], align: :invalid_align)
      assert msg.align == :left
    end

    test "invalid add_line falls back to :none" do
      msg = MessageInfo.new(["Hello"], add_line: :invalid_line)
      assert msg.add_line == :none
    end

    test "nil align falls back to :left" do
      msg = MessageInfo.new(["Hello"], align: nil)
      assert msg.align == :left
    end

    test "nil add_line falls back to :none" do
      msg = MessageInfo.new(["Hello"], add_line: nil)
      assert msg.add_line == :none
    end
  end

  describe "get_text/1" do
    test "returns concatenated text from all chunks" do
      msg = MessageInfo.new(["Hello", " ", "World"])
      assert MessageInfo.get_text(msg) == "Hello World"
    end

    test "returns text from single chunk" do
      msg = MessageInfo.new(["Hello"])
      assert MessageInfo.get_text(msg) == "Hello"
    end

    test "returns empty string for empty chunks" do
      msg = MessageInfo.new([])
      assert MessageInfo.get_text(msg) == ""
    end

    test "returns text preserving spaces" do
      msg = MessageInfo.new(["Hello", "   ", "World"])
      assert MessageInfo.get_text(msg) == "Hello   World"
    end

    test "returns text from ChunkText with unicode" do
      msg = MessageInfo.new(["Hello 世界"])
      assert MessageInfo.get_text(msg) == "Hello 世界"
    end
  end

  describe "get_width/1" do
    test "returns length of text" do
      msg = MessageInfo.new(["Hello"])
      assert MessageInfo.get_width(msg) == 5
    end

    test "returns combined width of multiple chunks" do
      msg = MessageInfo.new(["Hello", " ", "World"])
      assert MessageInfo.get_width(msg) == 11
    end

    test "returns 0 for empty message" do
      msg = MessageInfo.new([])
      assert MessageInfo.get_width(msg) == 0
    end

    test "returns correct width for unicode" do
      msg = MessageInfo.new(["Hello 世界"])
      assert MessageInfo.get_width(msg) == 8
    end
  end

  describe "normalize_padding/1" do
    test "converts integer to symmetric tuple" do
      assert MessageInfo.normalize_padding(2) == {2, 2, 2, 2}
    end

    test "returns tuple as-is" do
      assert MessageInfo.normalize_padding({1, 2, 3, 4}) == {1, 2, 3, 4}
    end

    test "handles zero" do
      assert MessageInfo.normalize_padding(0) == {0, 0, 0, 0}
    end

    test "handles large padding" do
      assert MessageInfo.normalize_padding(10) == {10, 10, 10, 10}
    end

    test "handles asymmetric tuple" do
      assert MessageInfo.normalize_padding({1, 2, 3, 4}) == {1, 2, 3, 4}
    end
  end

  describe "struct fields" do
    test "has all expected fields" do
      msg = MessageInfo.new(["Hello"])
      assert Map.has_key?(msg, :chunks)
      assert Map.has_key?(msg, :align)
      assert Map.has_key?(msg, :padding)
      assert Map.has_key?(msg, :add_line)
      assert Map.has_key?(msg, :raw_coords)
    end
  end

  describe "valid aligns" do
    test ":left is valid" do
      msg = MessageInfo.new(["Hello"], align: :left)
      assert msg.align == :left
    end

    test ":center is valid" do
      msg = MessageInfo.new(["Hello"], align: :center)
      assert msg.align == :center
    end

    test ":right is valid" do
      msg = MessageInfo.new(["Hello"], align: :right)
      assert msg.align == :right
    end

    test ":justified is valid" do
      msg = MessageInfo.new(["Hello"], align: :justified)
      assert msg.align == :justified
    end
  end

  describe "valid add_line values" do
    test ":before is valid" do
      msg = MessageInfo.new(["Hello"], add_line: :before)
      assert msg.add_line == :before
    end

    test ":after is valid" do
      msg = MessageInfo.new(["Hello"], add_line: :after)
      assert msg.add_line == :after
    end

    test ":both is valid" do
      msg = MessageInfo.new(["Hello"], add_line: :both)
      assert msg.add_line == :both
    end

    test ":none is valid" do
      msg = MessageInfo.new(["Hello"], add_line: :none)
      assert msg.add_line == :none
    end
  end

  describe "edge cases" do
    test "converts non-string items to ChunkText" do
      msg = MessageInfo.new([ChunkText.new("Hello")])
      assert length(msg.chunks) == 1
    end

    test "preserves ChunkText structs" do
      chunk = ChunkText.new("Hello", color: :red)
      msg = MessageInfo.new([chunk])
      assert hd(msg.chunks).color.name == :red
    end

    test "raw_coords can be nil" do
      msg = MessageInfo.new(["Hello"], raw_coords: nil)
      assert msg.raw_coords == nil
    end
  end
end
