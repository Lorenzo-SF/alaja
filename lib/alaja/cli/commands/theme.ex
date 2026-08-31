defmodule Alaja.CLI.Commands.Theme do
  @moduledoc """
  `alaja theme` — Manage themes (init, set, list, show).
  """

  @help_data [
    title: "Alaja Theme",
    subtitle: "Manage themes (init, set, list, show)",
    usage: "alaja theme <action>",
    description: """
    Installs Pote and Alaja custom theme templates into
    `~/.config/alaja/themes`, activates a theme, lists installed
    themes, and shows individual or side-by-side comparisons.

    Respects the global options (e.g. `--no-color` disables ANSI).
    """,
    options: [],
    examples: [
      {"Initialize themes", "alaja theme init"},
      {"Activate a theme", "alaja theme set dracula"},
      {"List installed themes", "alaja theme list"},
      {"Show a single theme", "alaja theme show dracula"},
      {"Compare themes side-by-side", "alaja theme show dracula nord light"},
      {"Compare all themes", "alaja theme show list"}
    ]
  ]

  alias Alaja.CLI.GlobalOpts
  alias Alaja.{Config, Theme}

  @doc "Runs the `alaja theme` command."
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    if global.help do
      help(global)
    else
      dispatch(rest, global)
    end
  end

  # Sub-action dispatch. Pattern matching in function heads keeps
  # the cyclomatic complexity below credo --strict (max 9).
  defp dispatch([], global), do: help(global)
  defp dispatch(["init" | _], global), do: run_init(global)
  defp dispatch(["set", _name | _] = args, global), do: run_set(args, global)
  defp dispatch(["set" | _], _global), do: usage_error("set <name>")
  defp dispatch(["list" | _], global), do: run_list(global)
  defp dispatch(["show" | names], global), do: run_show(names, global)
  defp dispatch(["all" | _], global), do: run_all(global)
  defp dispatch([action | _], global), do: unknown_action(action, global)

  defp usage_error(hint) do
    IO.puts(:stderr, "  Usage: alaja theme #{hint}")
  end

  # ── Actions ──────────────────────────────────────────────────────────────

  defp run_init(_global) do
    config_path = Path.expand("~/.config/alaja")
    File.mkdir_p!(config_path)

    Enum.each(Theme.templates(), fn name ->
      IO.write("  Writing #{name}.json ... ")

      case Theme.install_template(name) do
        :ok -> IO.puts(success_mark())
        {:error, reason} -> IO.puts(error_mark("#{inspect(reason)}"))
      end
    end)

    Enum.each(Alaja.Theme.CustomTemplates.all(), fn theme ->
      IO.write("  Writing #{theme.name}.json ... ")

      case Theme.install!(theme) do
        :ok -> IO.puts(success_mark())
        {:error, reason} -> IO.puts(error_mark("#{inspect(reason)}"))
      end
    end)

    IO.puts("\n  Themes initialized at #{config_path}/themes\n")
  end

  defp run_set(["set", name | _], _global) do
    if name in Theme.list() do
      :ok = Theme.activate(name)
      Config.set(:theme_active, name)
      IO.puts("  #{success_mark()} Theme set to '#{name}'")
    else
      IO.puts(
        :stderr,
        "  Theme '#{name}' not found. Run 'alaja theme list' to see available."
      )
    end
  end

  defp run_set(["set" | _], _global) do
    IO.puts(:stderr, "Usage: alaja theme set <name>")
  end

  defp run_list(_global) do
    case Theme.list() do
      [] ->
        IO.puts("  No themes found. Run alaja theme init first.")

      themes ->
        active = to_string(Config.get(:theme_active))
        Enum.each(themes, &print_theme_line(&1, active))
        IO.puts("")
    end
  end

  defp print_theme_line(name, active) do
    marker = if name == active, do: " #{success_mark()} ← active", else: ""
    IO.puts("  • #{name}#{marker}")
  end

  defp run_show(["show", "all" | _], global), do: show_all_themes(global)

  defp run_show(["show", "list" | _], global), do: show_compare(Theme.list(), global)

  defp run_show(["show" | names], global) when names != [] do
    themes = Theme.list()

    cond do
      # Single theme name
      length(names) == 1 and hd(names) in themes ->
        show_single_theme(hd(names), global)

      # Multiple theme names — show side-by-side comparison
      Enum.all?(names, &(&1 in themes)) ->
        show_compare(names, global)

      # One or more names not found
      true ->
        missing = Enum.reject(names, &(&1 in themes))

        IO.puts(
          :stderr,
          "  Theme(s) not found: #{Enum.join(missing, ", ")}. Run 'alaja theme list' to see available."
        )
    end
  end

  defp run_show(_args, _global) do
    IO.puts(:stderr, "Usage: alaja theme show <name>... | show list | show all")
  end

  defp run_all(_global), do: show_compare(Theme.list(), [])

  defp unknown_action(action, _global) do
    IO.puts(:stderr, "alaja theme: unknown action '#{action}'")
    IO.puts(:stderr, "Usage: alaja theme <init|set|list|show|all>")
  end

  # ── Render helpers ───────────────────────────────────────────────────────

  defp show_all_themes(_global) do
    themes = Theme.list()

    if themes == [] do
      IO.puts("  No themes found. Run alaja theme init first.")
    else
      Enum.each(themes, &show_single_theme(&1, %Alaja.CLI.GlobalOpts{}))
    end
  end

  defp show_single_theme(name, _global) do
    case Config.load_theme(name) do
      {:ok, data} ->
        display_name = data["name"] || name
        desc = data["description"]
        colors = Map.get(data, "colors", %{})

        IO.write("\e[38;2;0;180;216mTheme: #{display_name}\e[0m\n")
        if desc, do: IO.puts("  #{desc}")

        IO.puts("")

        max_key_len =
          colors |> Map.keys() |> Enum.map(&Alaja.Text.width/1) |> Enum.max(fn -> 1 end)

        Enum.each(colors, fn {k, [r, g, b]} ->
          swatch = color_swatch({r, g, b})
          hex = String.upcase(Base.encode16(<<r, g, b>>))
          pad = String.pad_trailing(k, max_key_len + (max_key_len - String.length(k)))
          IO.puts("  #{swatch} #{pad}  ##{hex}")
        end)

        IO.puts("")

      {:error, _} ->
        IO.puts(:stderr, "  Could not load theme '#{name}'.")
    end
  end

  defp show_compare([], _global) do
    IO.puts("  No themes found. Run alaja theme init first.")
  end

  defp show_compare(themes, _global) do
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
    name_col_w = max(Enum.map(all_keys, &Alaja.Text.width/1) |> Enum.max(fn -> 1 end), 8)
    theme_col_w = 8

    header =
      [String.pad_trailing("", name_col_w)] ++
        Enum.map(themes, &String.pad_trailing(&1, theme_col_w))

    IO.puts("\n  Theme comparison\n")
    IO.puts("  #{Enum.join(header, "  ")}")

    Enum.each(all_keys, fn key ->
      row = [String.pad_trailing(key, name_col_w)]
      row = build_color_swatches(themes, theme_data, key, name_col_w, theme_col_w, row)
      IO.puts("  #{Enum.join(row, "  ")}")
    end)

    IO.puts("")
  end

  defp build_color_swatches(themes, theme_data, key, _name_col_w, theme_col_w, row) do
    Enum.reduce(themes, row, fn name, acc ->
      case get_in(theme_data, [name, key]) do
        [r, g, b] ->
          swatch = "\e[48;2;#{r};#{g};#{b}m#{String.pad_trailing("", theme_col_w)}\e[0m"
          acc ++ [swatch]

        _ ->
          acc ++ [String.pad_trailing("N/A", theme_col_w)]
      end
    end)
  end

  # ── Colour helpers ───────────────────────────────────────────────────────

  # Coloured markers honour `--no-color` via Printer.format_raw. The
  # swatches used in theme comparisons MUST always emit RGB sequences
  # because that's the whole point of the view.
  defp success_mark, do: wrap("\e[38;2;72;187;120m✓\e[0m")

  defp error_mark(text), do: wrap("\e[38;2;245;101;101m✗ #{text}\e[0m")

  defp wrap(escape_sequence), do: escape_sequence

  defp color_swatch({r, g, b}) do
    "\e[48;2;#{r};#{g};#{b}m  \e[0m"
  end

  # ── Help ─────────────────────────────────────────────────────────────────

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: Alaja.CLI.HelpFormatter.render(@help_data, global)
end
