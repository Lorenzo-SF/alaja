defmodule Alaja.CLI.Commands.Config do
  @moduledoc """
  `alaja config` — Manage Alaja configuration and themes.
  """

  alias Alaja.Components.Header
  alias Alaja.Config

  # Only keys that Alaja itself owns and persists.
  @config_keys [:color_depth, :theme_active]
  @valid_color_depths [:truecolor, :xterm256, :ansi16]

  @spec run() :: :ok | no_return()
  def run, do: help()

  @spec run([String.t()]) :: :ok | no_return()
  @doc false
  def run(args) do
    {opts, rest, _} = OptionParser.parse(args, switches: [show: :boolean], aliases: [s: :show])

    if Keyword.get(opts, :show) do
      show_config()
    else
      dispatch_action(rest)
    end
  end

  defp dispatch_action([]), do: help()
  defp dispatch_action(["--help"]), do: help()
  defp dispatch_action(["-h"]), do: help()
  defp dispatch_action(["init"]), do: init_config()
  defp dispatch_action(["get", key | _]), do: get_config(key)
  defp dispatch_action(["set", key, val | _]), do: set_config(key, val)
  defp dispatch_action(["theme", "list"]), do: list_themes()
  defp dispatch_action(["theme", "set", name]), do: set_theme(name)
  defp dispatch_action(["theme" | _]), do: theme_help()

  defp dispatch_action(_) do
    IO.puts(:stderr, "alaja config: unknown action")
    help()
    System.halt(1)
  end

  defp show_config do
    IO.puts("\n\e[38;2;0;180;216mAlaja Configuration\e[0m\n")

    configs = [
      {"color_depth", Config.get(:color_depth)},
      {"theme_active", Config.get(:theme_active)},
      {"config_file", Config.config_file_path()}
    ]

    Enum.each(configs, fn {key, value} ->
      IO.puts("  \e[38;2;0;180;216m#{String.pad_trailing(key, 20)}\e[0m #{inspect(value)}")
    end)

    IO.puts("")
  end

  defp get_config(key_str) do
    key = safe_key(key_str)

    if key do
      IO.puts("  #{key_str}: #{inspect(Config.get(key))}")
    else
      IO.puts(:stderr, "Unknown config key: #{key_str}")
      IO.puts("Available: #{Enum.map_join(@config_keys, ", ", &to_string/1)}")
    end
  end

  defp set_config(key_str, value_str) do
    key = safe_key(key_str)

    if key do
      do_set_config(key, value_str)
    else
      IO.puts(:stderr, "Unknown config key: #{key_str}")
      IO.puts("Available: #{Enum.map_join(@config_keys, ", ", &to_string/1)}")
    end
  end

  defp do_set_config(:color_depth, v) do
    case v do
      "truecolor" ->
        persist_and_confirm(:color_depth, :truecolor, "color_depth set to truecolor")

      "xterm256" ->
        persist_and_confirm(:color_depth, :xterm256, "color_depth set to xterm256")

      "ansi16" ->
        persist_and_confirm(:color_depth, :ansi16, "color_depth set to ansi16")

      _ ->
        IO.puts(
          :stderr,
          "Invalid color_depth: #{v} (valid: #{Enum.join(@valid_color_depths, ", ")})"
        )
    end
  end

  defp do_set_config(:theme_active, v), do: set_theme(v)

  defp persist_and_confirm(key, value, msg) do
    Config.set(key, value)
    IO.puts("  \e[38;2;72;187;120m✓\e[0m #{msg}")
  end

  defp init_config do
    config_path = Path.expand("~/.config/alaja")
    themes_path = Path.expand("~/.config/alaja/themes")

    IO.write("  Creating #{config_path} ... ")

    case File.mkdir_p(config_path) do
      :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
      {:error, r} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(r)}\e[0m")
    end

    IO.write("  Creating #{themes_path} ... ")

    case File.mkdir_p(themes_path) do
      :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
      {:error, r} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(r)}\e[0m")
    end

    themes = [
      {"default.json", default_theme()},
      {"dracula.json", dracula_theme()},
      {"monokai.json", monokai_theme()},
      {"nord.json", nord_theme()},
      {"light.json", light_theme()}
    ]

    write_themes(themes, themes_path)

    config_file = Path.join(config_path, "alaja.conf")

    unless File.exists?(config_file) do
      IO.write("  Writing default config ... ")

      default = %{
        "color_depth" => "truecolor",
        "theme_active" => "default"
      }

      case File.write(config_file, Jason.encode!(default, pretty: true)) do
        :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
        {:error, r} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(r)}\e[0m")
      end
    end

    IO.puts("\n  \e[38;2;72;187;120mConfiguration initialized at #{config_path}\e[0m\n")
  end

  defp write_themes(themes, themes_path) do
    Enum.each(themes, fn {name, content} ->
      path = Path.join(themes_path, name)
      unless File.exists?(path), do: write_theme_file(path, name, content)
    end)
  end

  defp write_theme_file(path, name, content) do
    IO.write("  Writing #{name} ... ")

    case File.write(path, content) do
      :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
      {:error, r} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(r)}\e[0m")
    end
  end

  defp list_themes do
    themes_path = Path.expand("~/.config/alaja/themes")

    if File.exists?(themes_path) do
      case File.ls(themes_path) do
        {:ok, files} -> handle_theme_files(files)
        {:error, r} -> IO.puts("  Error reading themes: #{inspect(r)}")
      end
    else
      IO.puts("  Themes directory not found. Run \e[38;2;0;180;216malaja config init\e[0m first.")
    end
  end

  defp handle_theme_files(files) do
    json = Enum.filter(files, &String.ends_with?(&1, ".json"))

    if json == [] do
      IO.puts("  No themes found. Run \e[38;2;0;180;216malaja config init\e[0m first.")
    else
      show_themes(json)
    end
  end

  defp show_themes(files) do
    IO.puts("\n  \e[38;2;0;180;216mAvailable themes:\e[0m")
    active = to_string(Config.get(:theme_active))

    Enum.each(files, fn f ->
      name = String.replace(f, ".json", "")
      marker = if name == active, do: " \e[38;2;72;187;120m← active\e[0m", else: ""
      IO.puts("    • #{name}#{marker}")
    end)

    IO.puts("")
  end

  defp set_theme(name) do
    theme_file = Path.join(Path.expand("~/.config/alaja/themes"), "#{name}.json")

    if File.exists?(theme_file) do
      apply_theme(name)
      Config.set(:theme_active, name)
      IO.puts("  \e[38;2;72;187;120m✓\e[0m Theme set to '#{name}'")
    else
      IO.puts(
        :stderr,
        "  Theme '#{name}' not found. Run 'alaja config theme list' to see available."
      )
    end
  end

  defp apply_theme(name) do
    case Config.load_theme(name) do
      {:ok, theme_data} ->
        colors = Map.get(theme_data, "colors", %{})
        Application.put_env(:alaja, :theme_colors, colors)

      {:error, _} ->
        IO.puts(:stderr, "Error: theme '#{name}' not found or invalid")
        System.halt(1)
    end
  end

  defp theme_help, do: IO.puts("  Usage: alaja config theme <list|set NAME>")

  # Map user-supplied string to a known atom without String.to_atom/1.
  defp safe_key("color_depth"), do: :color_depth
  defp safe_key("theme_active"), do: :theme_active
  defp safe_key(_), do: nil

  @spec help() :: :ok
  @doc false
  def help do
    Header.print("Alaja Config", subtitle: "Manage configuration and themes", size: :small)

    IO.puts("""

    USAGE
      alaja config <action>

    ACTIONS
      init                Initialize ~/.config/alaja with defaults
      set <key> <value>   Set a configuration value (persisted to disk)
      get <key>           Get a configuration value
      theme list          List available themes
      theme set <name>    Set the active theme
      --show              Print current configuration

    CONFIGURABLE KEYS
      color_depth         Color depth: truecolor, xterm256, ansi16
      theme_active        Active theme name

    EXAMPLES
      alaja config init
      alaja config set color_depth xterm256
      alaja config set theme_active dracula
      alaja config theme list
      alaja config --show
    """)
  end

  # ---------------------------------------------------------------------------
  # Theme JSON templates
  # ---------------------------------------------------------------------------

  defp default_theme,
    do:
      theme_json("default", "Default dark theme with cyan/blue accents", %{
        primary: [0, 180, 216],
        secondary: [58, 171, 163],
        ternary: [255, 128, 0],
        quaternary: [155, 66, 226],
        no_color: [248, 248, 242],
        background: [40, 44, 52],
        success: [72, 187, 120],
        warning: [237, 137, 54],
        error: [245, 101, 101],
        info: [66, 153, 225]
      })

  defp dracula_theme,
    do:
      theme_json("dracula", "Dracula color palette", %{
        primary: [189, 147, 249],
        secondary: [68, 71, 90],
        ternary: [255, 184, 108],
        quaternary: [255, 121, 198],
        no_color: [248, 248, 242],
        background: [40, 42, 54],
        success: [80, 250, 123],
        warning: [241, 250, 140],
        error: [255, 85, 85],
        info: [139, 233, 253]
      })

  defp monokai_theme,
    do:
      theme_json("monokai", "Monokai color palette", %{
        primary: [166, 226, 46],
        secondary: [102, 217, 239],
        ternary: [253, 151, 31],
        quaternary: [174, 129, 255],
        no_color: [248, 248, 242],
        background: [39, 40, 34],
        success: [166, 226, 46],
        warning: [230, 219, 116],
        error: [249, 38, 114],
        info: [102, 217, 239]
      })

  defp nord_theme,
    do:
      theme_json("nord", "Arctic, north-bluish color palette", %{
        primary: [136, 192, 208],
        secondary: [76, 86, 106],
        ternary: [143, 188, 187],
        quaternary: [94, 129, 172],
        no_color: [236, 239, 244],
        background: [46, 52, 64],
        success: [163, 190, 140],
        warning: [235, 203, 139],
        error: [191, 97, 106],
        info: [129, 161, 193]
      })

  defp light_theme,
    do:
      theme_json("light", "Clean light color palette", %{
        primary: [52, 144, 220],
        secondary: [113, 128, 150],
        ternary: [237, 137, 54],
        quaternary: [159, 122, 234],
        no_color: [45, 55, 72],
        background: [247, 250, 252],
        success: [56, 161, 105],
        warning: [214, 158, 46],
        error: [229, 62, 62],
        info: [49, 130, 206]
      })

  defp theme_json(name, desc, colors) do
    colors_map =
      Enum.map_join(colors, ",\n        ", fn {k, [r, g, b]} ->
        "\"#{k}\": {\"rgb\": [#{r}, #{g}, #{b}]}"
      end)

    "{\n  \"name\": \"#{name}\",\n  \"version\": \"1.0.0\",\n  \"description\": \"#{desc}\",\n  \"colors\": {\n        #{colors_map}\n  },\n  \"effects\": {\n    \"border_style\": \"rounded\"\n  }\n}"
  end
end
