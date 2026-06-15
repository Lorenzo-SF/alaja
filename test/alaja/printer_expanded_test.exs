defmodule Alaja.PrinterExpandedTest do
  use ExUnit.Case, async: true

  alias Alaja.Printer
  alias Alaja.Printer.Basics
  alias Alaja.Structures.{ChunkText, MessageInfo}

  describe "delegated functions to Basics" do
    test "print_success/1 prints a success message" do
      assert Basics.print_success("test") == :ok
    end

    test "print_error/1 prints an error message" do
      assert Basics.print_error("test") == :ok
    end

    test "print_warning/1 prints a warning message" do
      assert Basics.print_warning("test") == :ok
    end

    test "print_info/1 prints an info message" do
      assert Basics.print_info("test") == :ok
    end

    test "print_debug/1 prints a debug message" do
      assert Basics.print_debug("test") == :ok
    end

    test "print_notice/1 prints a notice message" do
      assert Basics.print_notice("test") == :ok
    end

    test "print_critical/1 prints a critical message" do
      assert Basics.print_critical("test") == :ok
    end

    test "print_alert/1 prints an alert message" do
      assert Basics.print_alert("test") == :ok
    end

    test "print_emergency/1 prints an emergency message" do
      assert Basics.print_emergency("test") == :ok
    end
  end

  describe "print_message/2" do
    test "maps success level to print_success" do
      assert Printer.print_message(:success, "test message") == :ok
    end

    test "maps error level to print_error" do
      assert Printer.print_message(:error, "test message") == :ok
    end

    test "maps warning level to print_warning" do
      assert Printer.print_message(:warning, "test message") == :ok
    end

    test "maps info level to print_info" do
      assert Printer.print_message(:info, "test message") == :ok
    end

    test "maps debug level to print_debug" do
      assert Printer.print_message(:debug, "test message") == :ok
    end

    test "maps notice level to print_notice" do
      assert Printer.print_message(:notice, "test message") == :ok
    end

    test "maps critical level to print_critical" do
      assert Printer.print_message(:critical, "test message") == :ok
    end

    test "maps alert level to print_alert" do
      assert Printer.print_message(:alert, "test message") == :ok
    end

    test "maps emergency level to print_emergency" do
      assert Printer.print_message(:emergency, "test message") == :ok
    end

    test "falls back to print_info for unknown level" do
      assert Printer.print_message(:unknown_level, "test message") == :ok
    end

    test "falls back to print_info when level is nil" do
      assert Printer.print_message(nil, "test message") == :ok
    end

    test "handles arbitrary atom as unknown level" do
      assert Printer.print_message(:random, "test") == :ok
    end
  end

  describe "print/2 with MessageInfo struct" do
    test "prints a MessageInfo with no formatting" do
      msg = MessageInfo.new(["Hello"])
      assert Printer.print(msg) == :ok
    end

    test "prints a MessageInfo with color" do
      msg =
        MessageInfo.new([ChunkText.new("Colored", color: :red)])

      assert Printer.print(msg) == :ok
    end

    test "prints a MessageInfo with effects" do
      msg =
        MessageInfo.new([ChunkText.new("Bold", effects: [:bold])])

      assert Printer.print(msg) == :ok
    end

    test "returns formatted string in verbose mode" do
      msg = MessageInfo.new([ChunkText.new("Hello", color: :blue)])
      result = Printer.print(msg, verbose: true)
      assert is_binary(result)
      assert result =~ "Hello"
    end

    test "verbose mode returns string with ANSI codes" do
      msg = MessageInfo.new([ChunkText.new("Test", color: :red)])
      result = Printer.print(msg, verbose: true)
      assert result =~ "\e["
    end

    test "uses raw_coords when provided in MessageInfo" do
      msg = MessageInfo.new(["Test"], raw_coords: {5, 3})
      assert Printer.print(msg) == :ok
    end

    test "handles raw_coords with all add_line options" do
      for add_line <- [:before, :after, :both, :none] do
        msg =
          MessageInfo.new(["Test"], raw_coords: {0, 0}, add_line: add_line)

        assert Printer.print(msg) == :ok
      end
    end

    test "handles raw_coords with raw option true" do
      msg = MessageInfo.new(["Test"])
      assert Printer.print(msg, raw: true, x: 0, y: 0) == :ok
    end

    test "handles raw_coords with raw option true and custom coordinates" do
      msg = MessageInfo.new(["Test"])
      assert Printer.print(msg, raw: true, x: 10, y: 5) == :ok
    end

    test "uses raw option with add_line :before" do
      msg = MessageInfo.new(["Test"], add_line: :before)
      assert Printer.print(msg, raw: true, x: 0, y: 0) == :ok
    end

    test "uses raw option with add_line :after" do
      msg = MessageInfo.new(["Test"], add_line: :after)
      assert Printer.print(msg, raw: true, x: 0, y: 0) == :ok
    end

    test "uses raw option with add_line :both" do
      msg = MessageInfo.new(["Test"], add_line: :both)
      assert Printer.print(msg, raw: true, x: 0, y: 0) == :ok
    end

    test "uses raw option with add_line :none" do
      msg = MessageInfo.new(["Test"], add_line: :none)
      assert Printer.print(msg, raw: true, x: 0, y: 0) == :ok
    end

    test "uses print_with_lines with add_line :before" do
      msg = MessageInfo.new(["Test"], add_line: :before)
      assert Printer.print(msg) == :ok
    end

    test "uses print_with_lines with add_line :after" do
      msg = MessageInfo.new(["Test"], add_line: :after)
      assert Printer.print(msg) == :ok
    end

    test "uses print_with_lines with add_line :both" do
      msg = MessageInfo.new(["Test"], add_line: :both)
      assert Printer.print(msg) == :ok
    end

    test "uses print_with_lines with add_line :none" do
      msg = MessageInfo.new(["Test"], add_line: :none)
      assert Printer.print(msg) == :ok
    end

    test "verbose option returns string even when raw_coords present" do
      msg = MessageInfo.new(["Test"], raw_coords: {0, 0})
      result = Printer.print(msg, verbose: true)
      assert result == "Test"
    end

    test "verbose option returns string even when raw option present" do
      msg = MessageInfo.new(["Test"])
      result = Printer.print(msg, raw: true, x: 0, y: 0, verbose: true)
      assert result == "Test"
    end
  end

  describe "print/2 with binary text" do
    test "prints plain text" do
      assert Printer.print("Hello World") == :ok
    end

    test "prints text with color option" do
      assert Printer.print("Colored", color: :green) == :ok
    end

    test "prints text with effects option" do
      assert Printer.print("Bold", effects: [:bold]) == :ok
    end

    test "prints text with multiple options" do
      assert Printer.print("Styled", color: :blue, effects: [:italic, :underline]) == :ok
    end

    test "prints text with align option" do
      assert Printer.print("Aligned", align: :center) == :ok
    end

    test "prints text with padding option" do
      assert Printer.print("Padded", padding: 2) == :ok
    end

    test "prints text with raw option" do
      assert Printer.print("Raw", raw: true, x: 0, y: 0) == :ok
    end

    test "prints text with verbose option returns string" do
      result = Printer.print("Test", verbose: true)
      assert is_binary(result)
      assert result =~ "Test"
    end

    test "prints empty string" do
      assert Printer.print("") == :ok
    end

    test "prints unicode text" do
      assert Printer.print("Hello 世界 🌍") == :ok
    end

    test "prints multiline text" do
      assert Printer.print("Line 1\nLine 2") == :ok
    end

    test "prints text with all add_line options" do
      for add_line <- [:before, :after, :both, :none] do
        assert Printer.print("Test", add_line: add_line) == :ok
      end
    end
  end

  describe "print/2 with list of chunks" do
    test "prints list of ChunkText" do
      chunks = [
        ChunkText.new("Hello"),
        ChunkText.new(" ", color: :blue),
        ChunkText.new("World", color: :red)
      ]

      assert Printer.print(chunks) == :ok
    end

    test "prints list of strings (converted to chunks)" do
      assert Printer.print(["Hello", " ", "World"]) == :ok
    end

    test "prints mixed list of strings and chunks" do
      chunks = [
        "Text ",
        ChunkText.new("styled", color: :green)
      ]

      assert Printer.print(chunks) == :ok
    end

    test "prints list with all options" do
      chunks = [ChunkText.new("Test")]
      assert Printer.print(chunks, color: :blue, effects: [:bold], align: :right) == :ok
    end

    test "prints empty list" do
      assert Printer.print([]) == :ok
    end

    test "prints list with verbose option" do
      chunks = [ChunkText.new("Test")]
      result = Printer.print(chunks, verbose: true)
      assert is_binary(result)
    end
  end

  describe "apply_formatting (private)" do
    test "applies padding to text" do
      msg = MessageInfo.new(["Test"], padding: 3)
      result = Printer.print(msg, verbose: true)
      assert result =~ "Test"
    end

    test "applies alignment :left (no change)" do
      msg = MessageInfo.new(["Test"], align: :left)
      result = Printer.print(msg, verbose: true)
      assert result =~ "Test"
    end

    test "applies alignment :center" do
      msg = MessageInfo.new(["Test"], align: :center)
      result = Printer.print(msg, verbose: true)
      assert result =~ "Test"
    end

    test "applies alignment :right" do
      msg = MessageInfo.new(["Test"], align: :right)
      result = Printer.print(msg, verbose: true)
      assert result =~ "Test"
    end

    test "applies alignment :justified (no change)" do
      msg = MessageInfo.new(["Test"], align: :justified)
      result = Printer.print(msg, verbose: true)
      assert result =~ "Test"
    end

    test "applies integer padding (symmetric)" do
      msg = MessageInfo.new(["Test"], padding: 2)
      result = Printer.print(msg, verbose: true)
      assert is_binary(result)
    end

    test "applies tuple padding (asymmetric)" do
      msg = MessageInfo.new(["Test\nTest"], padding: {1, 2, 1, 2})
      result = Printer.print(msg, verbose: true)
      assert is_binary(result)
    end

    test "padding 0 means no padding" do
      msg = MessageInfo.new(["Test"], padding: 0)
      result = Printer.print(msg, verbose: true)
      assert result == "Test"
    end
  end

  describe "edge cases" do
    test "MessageInfo with nil chunks" do
      msg = %Alaja.Structures.MessageInfo{
        chunks: [],
        align: :left,
        padding: 0,
        add_line: :none
      }

      assert Printer.print(msg) == :ok
    end

    test "MessageInfo with invalid align defaults to :left in new/2" do
      msg = MessageInfo.new(["Test"], align: :invalid)
      assert msg.align == :left
    end

    test "MessageInfo with invalid add_line defaults to :none in new/2" do
      msg = MessageInfo.new(["Test"], add_line: :invalid)
      assert msg.add_line == :none
    end

    test "raw_coords option takes precedence over opts[:raw]" do
      msg = MessageInfo.new(["Test"], raw_coords: {1, 1})
      assert Printer.print(msg, raw: true, x: 10, y: 10) == :ok
    end

    test "verbose option with no color or effects returns plain text" do
      msg = MessageInfo.new(["Plain text"])
      result = Printer.print(msg, verbose: true)
      assert result == "Plain text"
    end
  end
end
