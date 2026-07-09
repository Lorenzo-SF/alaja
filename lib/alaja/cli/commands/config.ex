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

  defp do_set_config(:theme_active, v) do
    if v in Theme.list() do
      :ok = Theme.activate(v)
      Config.set(:theme_active, v)
      IO.puts("  \e[38;2;72;187;120m✓\e[0m Theme set to '#{v}'")
    else
      IO.puts(:stderr, "  Theme '#{v}' not found. Run 'alaja theme list' to see available.")
    end
  end

  defp persist_and_confirm(key, value, msg) do
    Config.set(key, value)
    IO.puts("  \e[38;2;72;187;120m✓\e[0m #{msg}")
  end

  defp init_config do
    config_path = Path.expand("~/.config/alaja")
    mkdir_p!(config_path)
    write_default_config(config_path)

    IO.puts("\n  \e[38;2;72;187;120mConfiguration initialized at #{config_path}\e[0m\n")
    IO.puts("  Run \e[38;2;0;180;216malaja theme init\e[0m to install default themes.")
  end

  defp mkdir_p!(config_path) do
    IO.write("  Creating #{config_path} ... ")

    case File.mkdir_p(config_path) do
      :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
      {:error, r} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(r)}\e[0m")
    end
  end

  @doc false
  def install_theme_templates do
    # Install built-in templates from Pote
    Enum.each(Theme.templates(), fn name ->
      IO.write("  Writing #{name}.json ... ")

      case Theme.install_template(name) do
        :ok -> IO.puts("\e[38;2;72;187;120m✓\e[0m")
        {:error, reason} -> IO.puts("\e[38;2;245;101;101m✗ #{inspect(reason)}\e[0m")
      end
    end)

    # Install Alaja's own custom templates on top
    Enum.each(Alaja.Theme.CustomTemplates.all(), fn theme ->
      IO.write("  Writing #{theme.name}.json ... ")

      case Theme.install!(theme) do
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
      --show              Print current configuration

    CONFIGURABLE KEYS
      color_depth         Color depth: truecolor, xterm256, ansi16
      theme_active        Active theme name

    THEMES
      Use `alaja theme` to manage themes (init, set, list, show).

    EXAMPLES
      alaja config init
      alaja config set color_depth xterm256
      alaja config --show
    """)
  end
end
