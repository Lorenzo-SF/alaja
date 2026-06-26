defmodule Alaja.Config do
  @moduledoc """
  Configuration management for Alaja CLI applications.

  Values are read from `~/.config/alaja/alaja.conf` on first access and
  kept in the Application environment for the lifetime of the process.
  `set/2` writes through to both the in-memory store and the conf file.

  ## Usage

      Alaja.Config.get(:color_depth, :truecolor)
      Alaja.Config.set(:color_depth, :xterm256)
      Alaja.Config.all()
  """

  @default_values %{
    color_depth: :truecolor,
    theme_active: :default
  }

  # Keys that are persisted to alaja.conf
  @persistent_keys [:color_depth, :theme_active]

  @doc "Gets a configuration value with fallback."
  @spec get(atom(), any()) :: any()
  def get(key, default \\ nil) do
    ensure_loaded()
    Application.get_env(:alaja, key, Map.get(@default_values, key, default))
  end

  @doc """
  Sets a configuration value.

  If the key is in the list of persistent keys it is also written to
  `~/.config/alaja/alaja.conf`. Always updates the in-memory store.
  """
  @spec set(atom(), any()) :: :ok
  def set(key, value) do
    Application.put_env(:alaja, key, value)

    if key in @persistent_keys do
      persist(key, value)
    end

    :ok
  end

  @doc "Returns all configuration values (merged defaults + env + file)."
  @spec all() :: keyword()
  def all do
    ensure_loaded()

    @default_values
    |> Keyword.new()
    |> Keyword.merge(Application.get_all_env(:alaja))
  end

  @doc "Returns available theme names."
  @spec list_themes() :: [String.t()]
  def list_themes do
    tp = themes_path()

    if File.exists?(tp) do
      case File.ls(tp) do
        {:ok, files} ->
          files
          |> Enum.filter(&String.ends_with?(&1, ".json"))
          |> Enum.map(&String.trim_trailing(&1, ".json"))

        _ ->
          []
      end
    else
      []
    end
  end

  @doc "Loads a theme by name."
  @spec load_theme(String.t()) :: {:ok, map()} | {:error, term()}
  def load_theme(name) do
    path = Path.join(themes_path(), "#{name}.json")

    with true <- File.exists?(path),
         {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      {:ok, data}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  Looks up a color key in the currently active theme.

  This is the public API used by the Pote theme resolver bridge:
  `"theme:<key>"` lookups in `Pote.Orchestrator` end up here when Alaja
  is the running app, so e.g. `alaja separator --color "theme:ternary"`
  resolves to the actual `ternary` color of the active theme, not Pote's
  hardcoded default palette.

  Returns `{:ok, {r, g, b}}` on hit, `:error` on miss (key absent or
  theme file unreadable).
  """
  @spec lookup_theme_color(String.t()) :: {:ok, {integer(), integer(), integer()}} | :error
  def lookup_theme_color(key) when is_binary(key) do
    theme_name = get(:theme_active, "default") |> to_string()

    case load_theme(theme_name) do
      {:ok, data} ->
        colors = Map.get(data, "colors", %{})

        case Map.get(colors, key) do
          [r, g, b] when is_integer(r) and is_integer(g) and is_integer(b) ->
            {:ok, {r, g, b}}

          _ ->
            :error
        end

      {:error, _} ->
        :error
    end
  end

  @doc "Returns the path to the config file."
  @spec config_file_path() :: String.t()
  def config_file_path do
    System.get_env("ALAJA_CONFIG_PATH") ||
      Path.join(System.user_home!(), ".config/alaja/alaja.conf")
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp themes_path do
    System.get_env("ALAJA_THEMES_PATH") ||
      Path.join(System.user_home!(), ".config/alaja/themes")
  end

  # Load the conf file into Application env exactly once per process.
  # Public so Alaja.Application can call it at startup before registering
  # the theme resolver (so :theme_active is already in app env when the
  # resolver reads it).
  @doc false
  @spec ensure_loaded() :: :ok
  def ensure_loaded do
    unless Application.get_env(:alaja, :__conf_loaded__) do
      load_from_disk()
      Application.put_env(:alaja, :__conf_loaded__, true)
    end

    :ok
  end

  defp load_from_disk do
    path = config_file_path()

    with true <- File.exists?(path),
         {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      Enum.each(data, &store_key_value/1)
    else
      _ -> :ok
    end
  end

  defp store_key_value({k, v}) do
    key = safe_atom(k)

    if key != nil do
      Application.put_env(:alaja, key, cast_value(key, v))
    end
  end

  # Write a single key back to the conf file (merge with existing content).
  defp persist(key, value) do
    path = config_file_path()

    current =
      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, map} -> map
            _ -> %{}
          end

        _ ->
          %{}
      end

    updated = Map.put(current, to_string(key), serialise_value(value))

    with :ok <- File.mkdir_p(Path.dirname(path)),
         {:ok, encoded} <- Jason.encode(updated, pretty: true),
         :ok <- File.write(path, encoded) do
      :ok
    else
      {:error, reason} ->
        IO.puts(:stderr, "Warning: could not persist config to #{path}: #{inspect(reason)}")
        :ok
    end
  end

  # Only allow atoms that are known keys to avoid atom-table exhaustion.
  defp safe_atom(str) when is_binary(str) do
    case str do
      "color_depth" -> :color_depth
      "theme_active" -> :theme_active
      _ -> nil
    end
  end

  defp safe_atom(_), do: nil

  # Cast string values read from JSON to the right Elixir types.
  defp cast_value(:color_depth, v) when is_binary(v) do
    case v do
      "truecolor" -> :truecolor
      "xterm256" -> :xterm256
      "ansi16" -> :ansi16
      _ -> :truecolor
    end
  end

  defp cast_value(:theme_active, v) when is_binary(v), do: v
  defp cast_value(_key, v), do: v

  defp serialise_value(v) when is_atom(v), do: Atom.to_string(v)
  defp serialise_value(v), do: v
end
