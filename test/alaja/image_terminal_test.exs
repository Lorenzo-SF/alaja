defmodule Alaja.ImageTerminalTest do
  use ExUnit.Case, async: true

  alias Alaja.ImageTerminal, as: Terminal

  describe "detect/0" do
    test "returns :kitty when KITTY_PID is set" do
      System.put_env("KITTY_PID", "12345")
      # Ensure other terminal env vars don't interfere
      System.delete_env("ITERM_SESSION_ID")
      System.delete_env("TERM_PROGRAM")
      assert Terminal.detect() == :kitty
      System.delete_env("KITTY_PID")
    end

    test "returns :iterm2 when ITERM_SESSION_ID is set" do
      System.put_env("ITERM_SESSION_ID", "test-session")
      System.delete_env("KITTY_PID")
      System.delete_env("TERM_PROGRAM")
      assert Terminal.detect() == :iterm2
      System.delete_env("ITERM_SESSION_ID")
    end

    test "returns :wezterm when TERM_PROGRAM is WezTerm" do
      System.put_env("TERM_PROGRAM", "WezTerm")
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      assert Terminal.detect() == :wezterm
      System.delete_env("TERM_PROGRAM")
    end

    test "returns :ghostty when TERM_PROGRAM is ghostty" do
      System.put_env("TERM_PROGRAM", "ghostty")
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      assert Terminal.detect() == :ghostty
      System.delete_env("TERM_PROGRAM")
    end

    test "returns :alacritty when TERM_PROGRAM is Alacritty" do
      System.put_env("TERM_PROGRAM", "Alacritty")
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      assert Terminal.detect() == :alacritty
      System.delete_env("TERM_PROGRAM")
    end

    test "returns :vscode when TERM_PROGRAM is vscode" do
      System.put_env("TERM_PROGRAM", "vscode")
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      assert Terminal.detect() == :vscode
      System.delete_env("TERM_PROGRAM")
    end

    test "returns :konsole when KONSOLE_VERSION is set" do
      System.put_env("KONSOLE_VERSION", "21.12.3")
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      System.delete_env("TERM_PROGRAM")
      assert Terminal.detect() == :konsole
      System.delete_env("KONSOLE_VERSION")
    end

    test "returns :foot when TERM is foot" do
      System.put_env("TERM", "foot")
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      System.delete_env("TERM_PROGRAM")
      System.delete_env("KONSOLE_VERSION")
      assert Terminal.detect() == :foot
      System.delete_env("TERM")
    end

    test "returns :unknown when no terminal is detected" do
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      System.delete_env("TERM_PROGRAM")
      System.delete_env("KONSOLE_VERSION")
      System.delete_env("TERM")
      assert Terminal.detect() == :unknown
    end
  end

  describe "image_protocol/0" do
    test "returns :kitty for kitty terminal" do
      System.put_env("KITTY_PID", "999")
      assert Terminal.image_protocol() == :kitty
      System.delete_env("KITTY_PID")
    end

    test "returns :iterm2 for iTerm2" do
      System.put_env("ITERM_SESSION_ID", "session")
      assert Terminal.image_protocol() == :iterm2
      System.delete_env("ITERM_SESSION_ID")
    end

    test "returns :sixel for alacritty" do
      System.put_env("TERM_PROGRAM", "Alacritty")
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      assert Terminal.image_protocol() == :sixel
      System.delete_env("TERM_PROGRAM")
    end

    test "returns :ascii for unknown terminal" do
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      System.delete_env("TERM_PROGRAM")
      System.delete_env("KONSOLE_VERSION")
      System.delete_env("TERM")
      assert Terminal.image_protocol() == :ascii
    end
  end

  describe "supports_images?/0" do
    test "returns true for kitty" do
      System.put_env("KITTY_PID", "123")
      assert Terminal.supports_images?() == true
      System.delete_env("KITTY_PID")
    end

    test "returns false for ascii protocol" do
      System.delete_env("KITTY_PID")
      System.delete_env("ITERM_SESSION_ID")
      System.delete_env("TERM_PROGRAM")
      System.delete_env("KONSOLE_VERSION")
      System.delete_env("TERM")
      assert Terminal.supports_images?() == false
    end
  end
end
