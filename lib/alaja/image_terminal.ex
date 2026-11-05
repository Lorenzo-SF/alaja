defmodule Alaja.ImageTerminal do
  @moduledoc """
  Terminal detection for image rendering.

  Detects terminal emulator and determines the best image
  rendering protocol to use.
  """

  @doc """
  Detects the terminal emulator.
  """
  @spec detect() :: atom()
  def detect do
    cond do
      env_set?("KITTY_PID") -> :kitty
      env_set?("ITERM_SESSION_ID") -> :iterm2
      true -> detect_by_env()
    end
  end

  @doc """
  Returns the image protocol for the current terminal.
  """
  @spec image_protocol() :: :kitty | :iterm2 | :sixel | :ascii
  def image_protocol, do: terminal_to_protocol(detect())

  @doc """
  Returns true if the terminal supports images.
  """
  @spec supports_images?() :: boolean()
  def supports_images?, do: image_protocol() != :ascii

  defp detect_by_env do
    case System.get_env("TERM_PROGRAM") do
      "WezTerm" -> :wezterm
      "ghostty" -> :ghostty
      "Alacritty" -> :alacritty
      "vscode" -> :vscode
      _ -> detect_legacy()
    end
  end

  defp detect_legacy do
    cond do
      env_set?("KONSOLE_VERSION") -> :konsole
      env_match?("TERM", "foot") -> :foot
      true -> :unknown
    end
  end

  defp terminal_to_protocol(:kitty), do: :kitty
  defp terminal_to_protocol(:ghostty), do: :kitty
  defp terminal_to_protocol(:wezterm), do: :kitty
  defp terminal_to_protocol(:iterm2), do: :iterm2
  defp terminal_to_protocol(:alacritty), do: :sixel
  defp terminal_to_protocol(:konsole), do: :kitty
  defp terminal_to_protocol(:foot), do: :sixel
  defp terminal_to_protocol(:vscode), do: :sixel
  defp terminal_to_protocol(_), do: :ascii

  defp env_set?(v), do: System.get_env(v) not in [nil, ""]
  defp env_match?(v, m), do: String.downcase(System.get_env(v) || "") == String.downcase(m)
end
