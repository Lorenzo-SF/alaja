defmodule Alaja.CLI.Commands.Theme do
  @moduledoc """
  `alaja theme` — Manage themes (init, set, list, show).
  """

  alias Alaja.CLI.Commands.Config, as: ConfigCmd
  alias Alaja.{Config, Theme}

  @spec run([String.t()]) :: :ok | no_return()
  def run([]), do: help()
  def run(["--help" | _]), do: help()
  def run(["-h" | _]), do: help()

  def run(["init" | _rest]) do
    # Install theme templates from Pote + Alaja custom templates
    config_path = Path.expand("~/.config/alaja")
    File.mkdir_p!(config_path)

    ConfigCmd.install_theme_templates()

    IO.puts("\n  \e[38;2;72;187;120mThemes initialized at #{config_path}/themes\e[0m\n")
  end

  def run(["set", name]) do
    if name in Theme.list() do
      :ok = Theme.activate(name)
      Config.set(:theme_active, name)
      IO.puts("  \e[38;2;72;187;120m✓\e[0m Theme set to '#{name}'")
    else
      IO.puts(
        :stderr,
        "  Theme '#{name}' not found. Run 'alaja theme list' to see available."
      )
    end
  end

  def run(["set" | _]) do
    IO.puts(:stderr, "Usage: alaja theme set <name>")
  end

  def run(["list"]) do
    themes = Theme.list()

    if themes == [] do
      IO.puts("  No themes found. Run \e[38;2;0;180;216malaja theme init\e[0m first.")
    else
      show_theme_list(themes)
    end
  end

  def run(["show", "all"]) do
    themes = Theme.list()

    if themes == [] do
      IO.puts("  No themes found. Run \e[38;2;0;180;216malaja theme init\e[0m first.")
    else
      Enum.each(themes, &show_single_theme/1)
    end
  end

  def run(["show", "list"]) do
    themes = Theme.list()

    if themes == [] do
      IO.puts("  No themes found. Run \e[38;2;0;180;216malaja theme init\e[0m first.")
    else
      show_theme_table_side_by_side(themes)
    end
  end

  def run(["show", name]) do
    if name in Theme.list() do
      show_single_theme(name)
    else
      IO.puts(:stderr, "  Theme '#{name}' not found. Run 'alaja theme list' to see available.")
    end
  end

  def run(["show" | _]) do
    IO.puts(:stderr, "Usage: alaja theme show <name> | list | all")
  end

  def run(_) do
    IO.puts(:stderr, "alaja theme: unknown action")
    help()
    exit({:shutdown, 1})
  end

  # ── Display helpers ─────────────────────────────────────────────────────

  defp show_theme_list(themes) do
    IO.puts("\n  \e[38;2;0;180;216mAvailable themes:\e[0m")
    active = to_string(Config.get(:theme_active))

    Enum.each(themes, fn name ->
      marker = if name == active, do: " \e[38;2;72;187;120m← active\e[0m", else: ""
      IO.puts("    \e[38;2;72;187;120m•\e[0m #{name}#{marker}")
    end)

    IO.puts("")
  end

  defp show_single_theme(name) do
    case Config.load_theme(name) do
      {:ok, data} ->
        display_name = data["name"] || name
        desc = data["description"]
        colors = Map.get(data, "colors", %{})

        IO.puts("\n  \e[38;2;0;180;216mTheme: #{display_name}\e[0m")
        if desc, do: IO.puts("  #{desc}")

        IO.puts("")

        max_key_len =
          colors |> Map.keys() |> Enum.map(&String.length/1) |> Enum.max(fn -> 1 end)

        Enum.each(colors, fn {k, [r, g, b]} ->
          swatch = "\e[48;2;#{r};#{g};#{b}m  \e[0m"
          hex = String.upcase(Base.encode16(<<r, g, b>>))

          IO.puts(
            "  #{swatch} \e[38;2;0;180;216m#{String.pad_trailing(k, max_key_len)}\e[0m  ##{hex}"
          )
        end)

        IO.puts("")

      {:error, _} ->
        IO.puts(:stderr, "  Could not load theme '#{name}'.")
    end
  end

  defp show_theme_table_side_by_side(themes) do
    # Load all themes and build a table with one column per theme
    theme_data =
      themes
      |> Enum.reduce(%{}, fn name, acc ->
        case Config.load_theme(name) do
          {:ok, data} -> Map.put(acc, name, Map.get(data, "colors", %{}))
          _ -> acc
        end
      end)

    if theme_data == %{} do
      IO.puts("  No theme data to display.")
      :ok
    else
      # Collect all color keys across all themes
      all_keys =
        theme_data
        |> Enum.flat_map(fn {_, colors} -> Map.keys(colors) end)
        |> Enum.uniq()
        |> Enum.sort()

      if all_keys == [] do
        IO.puts("  No color keys found in themes.")
        :ok
      else
        show_color_comparison(themes, theme_data, all_keys)
      end
    end
  end

  defp show_color_comparison(themes, theme_data, all_keys) do
    name_col_w = max(Enum.map(all_keys, &String.length/1) |> Enum.max(fn -> 1 end), 8)
    theme_col_w = 8

    header =
      [String.pad_trailing("color", name_col_w)] ++
        Enum.map(themes, &String.pad_trailing(&1, theme_col_w))

    IO.puts("\n  \e[38;2;0;180;216mTheme comparison\e[0m\n")
    IO.puts("  #{Enum.join(header, "  ")}")

    Enum.each(all_keys, fn key ->
      row = [String.pad_trailing(key, name_col_w)]
      row = build_color_swatches(themes, theme_data, key, name_col_w, theme_col_w, row)
      IO.puts("  #{Enum.join(row, "  ")}")
    end)

    IO.puts("")
  end

  # ── Help ────────────────────────────────────────────────────────────────

  @spec help() :: :ok
  def help do
    IO.puts("""

    USAGE
      alaja theme <action>

    ACTIONS
      init                Install default themes to ~/.config/alaja/themes
      set <name>          Activate a theme
      list                List available themes
      show <name>         Show a theme's color table
      show list           Show side-by-side color comparison
      show all            Show all themes sequentially

    EXAMPLES
      alaja theme init
      alaja theme set dracula
      alaja theme list
      alaja theme show dracula
    """)
  end

  defp build_color_swatches(themes, theme_data, key, _name_col_w, theme_col_w, row) do
    Enum.reduce(themes, row, fn name, acc ->
      case get_in(theme_data, [name, key]) do
        [r, g, b] ->
          swatch = "\e[48;2;#{r};#{g};#{b}m#{String.pad_trailing("", 6)}\e[0m"
          acc ++ [swatch]

        _ ->
          acc ++ [String.pad_trailing("-", theme_col_w)]
      end
    end)
  end
end
