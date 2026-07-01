defmodule Alaja.CLI.Commands.Config do
  @moduledoc """
  `alaja config` — Manage Alaja configuration and themes.
  """

  alias Alaja.Components.Header
  alias Alaja.{Config, Theme}

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
    exit({:shutdown, 1})
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

    mkdir_p!(config_path)
    install_theme_templates()
    write_default_config(config_path)

    IO.puts("\n  \e[38;2;72;187;120mConfiguration initialized at #{config_path}\e[0m\n")
  end

  defp mkdir_p!(config_path) do
    IO.write("  Creating #{config_path} ... ")

    case File.mkdir_p(config_path) do
      :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
      {:error, r} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(r)}\e[0m")
    end
  end

  defp install_theme_templates do
    Enum.each(Theme.templates(), fn name ->
      IO.write("  Writing #{name}.json ... ")

      case Theme.install_template(name) do
        :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
        {:error, reason} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(reason)}\e[0m")
      end
    end)
  end

  defp write_default_config(config_path) do
    config_file = Path.join(config_path, "alaja.conf")

    unless File.exists?(config_file) do
      IO.write("  Writing default config ... ")

      default = %{
        "color_depth" => "truecolor",
        "theme_active" => "default"
      }

      config_json =
        case Jason.encode(default, pretty: true) do
          {:ok, json} -> json
          {:error, _} -> "{}"
        end

      case File.write(config_file, config_json) do
        :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
        {:error, r} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(r)}\e[0m")
      end
    end
  end

  defp list_themes do
    themes = Theme.list()

    if themes == [] do
      IO.puts("  No themes found. Run \e[38;2;0;180;216malaja config init\e[0m first.")
    else
      show_themes(themes)
    end
  end

  defp show_themes(themes) do
    IO.puts("\n  \e[38;2;0;180;216mAvailable themes:\e[0m")
    active = to_string(Config.get(:theme_active))

    Enum.each(themes, fn name ->
      marker = if name == active, do: " \e[38;2;72;187;120m← active\e[0m", else: ""
      IO.puts("    • #{name}#{marker}")
    end)

    IO.puts("")
  end

  defp set_theme(name) do
    # Validate the theme exists in storage before activating. This is the
    # single source of truth — Alaja.Theme.list/0 reads the JSON files
    # written by Alaja.Theme.install_template/1.
    if name in Theme.list() do
      :ok = Theme.activate(name)
      Config.set(:theme_active, name)
      IO.puts("  \e[38;2;72;187;120m✓\e[0m Theme set to '#{name}'")
    else
      IO.puts(
        :stderr,
        "  Theme '#{name}' not found. Run 'alaja config theme list' to see available."
      )
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
end
