defmodule Alaja.PrinterTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Alaja.Printer

  describe "semantic print functions" do
    test "print_success/1 outputs with success gliphicons and message" do
      output = capture_io(fn -> Printer.print_success("Done") end)
      assert String.contains?(output, "[✓]")
      assert String.contains?(output, "Done")
      assert output =~ "\e["
    end

    test "print_error/1 outputs with error gliphicons and message" do
      output = capture_io(fn -> Printer.print_error("Failed") end)
      assert String.contains?(output, "[✗]")
      assert String.contains?(output, "Failed")
      assert output =~ "\e["
    end

    test "print_warning/1 outputs with warning gliphicons and message" do
      output = capture_io(fn -> Printer.print_warning("Careful") end)
      assert String.contains?(output, "[!]")
      assert String.contains?(output, "Careful")
      assert output =~ "\e["
    end

    test "print_info/1 outputs with info gliphicons and message" do
      output = capture_io(fn -> Printer.print_info("Note") end)
      assert String.contains?(output, "[i]")
      assert String.contains?(output, "Note")
      assert output =~ "\e["
    end

    test "print_debug/1 outputs with debug gliphicons and message" do
      output = capture_io(fn -> Printer.print_debug("Ping") end)
      # Debug uses [?] as its gliphicons
      assert String.contains?(output, "[?]")
      assert String.contains?(output, "Ping")
      assert output =~ "\e["
    end

    test "print_alert/1 outputs with alert gliphicons (inverted warning)" do
      output = capture_io(fn -> Printer.print_alert("Heads up") end)
      assert String.contains?(output, "[!]")
      assert String.contains?(output, "Heads up")
      assert output =~ "\e["
    end

    test "print_critical/1 outputs with critical gliphicons (inverted error)" do
      output = capture_io(fn -> Printer.print_critical("Severe") end)
      assert String.contains?(output, "[!!]")
      assert String.contains?(output, "Severe")
      assert output =~ "\e["
    end

    test "print_emergency/1 outputs with emergency gliphicons (inverted error, blink)" do
      output = capture_io(fn -> Printer.print_emergency("Panic") end)
      assert String.contains?(output, "[SOS]")
      assert String.contains?(output, "Panic")
      assert output =~ "\e["
    end

    test "print_happy/1 outputs with happy gliphicons and message" do
      output = capture_io(fn -> Alaja.Printer.Basics.print_happy("Yay") end)
      assert String.contains?(output, "[+]")
      assert String.contains?(output, "Yay")
      assert output =~ "\e["
    end

    test "print_sad/1 outputs with sad gliphicons and message" do
      output = capture_io(fn -> Alaja.Printer.Basics.print_sad("Aww") end)
      assert String.contains?(output, "[-]")
      assert String.contains?(output, "Aww")
      assert output =~ "\e["
    end

    test "print_notice/1 outputs with notice gliphicons and message" do
      output = capture_io(fn -> Printer.print_notice("FYI") end)
      assert String.contains?(output, "[i]")
      assert String.contains?(output, "FYI")
      assert output =~ "\e["
    end
  end

  describe "print_message/2" do
    test "falls back to white for unknown levels" do
      output = capture_io(fn -> Printer.print_message(:unknown_level, "Fallback") end)
      assert String.contains?(output, "Fallback")
    end

    test "handles alert and emergency" do
      out1 = capture_io(fn -> Printer.print_message(:alert, "A") end)
      assert String.contains?(out1, "[!]")
      assert out1 =~ "\e["

      out2 = capture_io(fn -> Printer.print_message(:emergency, "E") end)
      assert String.contains?(out2, "[SOS]")
      assert out2 =~ "\e["
    end

    test "handles critical and notice" do
      out1 = capture_io(fn -> Printer.print_message(:critical, "C") end)
      assert String.contains?(out1, "[!!]")
      assert out1 =~ "\e["

      out2 = capture_io(fn -> Printer.print_message(:notice, "N") end)
      assert String.contains?(out2, "[i]")
      assert out2 =~ "\e["
    end
  end

  describe "print/2 (custom prints)" do
    test "prints with options" do
      output =
        capture_io(fn ->
          Printer.print("Hello", color: :blue, effects: [:bold, :italic])
        end)

      assert String.contains?(output, "Hello")
      # Verifica códigos ANSI presentes
      assert output =~ "\e["
    end

    test "handles specific internal atoms" do
      output =
        capture_io(fn ->
          Printer.print("Alpha", color: :light_magenta)
        end)

      assert output =~ "Alpha"
      assert output =~ "\e["
    end

    test "handles tuple colors" do
      output =
        capture_io(fn ->
          Printer.print("RGB", color: {255, 128, 0})
        end)

      # RGB tuple produce códigos ANSI extendidos
      assert String.contains?(output, "RGB")
      assert output =~ "\e[38;2"
    end

    test "handles unsupported effects and unknown colors gracefully" do
      output =
        capture_io(fn ->
          Printer.print("Test", color: :invented_color, effects: [:invented_effect, :underline])
        end)

      # underline produce \e[4m
      assert String.contains?(output, "\e[4m")
      assert String.contains?(output, "Test")
    end

    test "apply_color fallback for other types" do
      # Si el color no es átomo ni tupla, debe manejarlo gracefully
      output = capture_io(fn -> Printer.print("x", color: "string_color") end)
      assert output =~ "x"
    end
  end
end
