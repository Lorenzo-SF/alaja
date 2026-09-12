defmodule Alaja.CLI.Commands.Theme do
  @moduledoc """
  `alaja theme` — Manage themes (init, set, list, show).

  iter-059 UX overhaul:
    * `alaja theme set` (no args) opens an interactive picker with arrow
      keys — no more guessing names.
    * `alaja theme list` uses `Alaja.Components.Table` for a compact
      swatch + name grid.
    * `alaja theme show <name>` shows one theme via `Table` too.
    * `alaja theme compare <names...>` paginates when > 3 themes.

  Respects the global options (`--no-color` disables ANSI).
  """

  @help_data [
    title: "Alaja Theme",
    subtitle: "Manage themes (init, set, list, show, compare)",
    usage: "alaja theme <action>",
    description: """
    Installs Pote and Alaja custom theme templates into
    `~/.config/alaja/themes`, activates a theme, lists installed
    themes, and shows individual or side-by-side comparisons.

    When invoked with no arguments for `set`, opens an interactive
    picker (arrow keys / Enter / Tab).

    Respects the global options (e.g. `--no-color` disables ANSI).
    """,
    options: [],
    examples: [
      {"Initialize themes", "alaja theme init"},
      {"Interactive picker", "alaja theme set"},
      {"Activate by name", "alaja theme set dracula"},
      {"List installed themes", "alaja theme list"},
      {"Show a single theme", "alaja theme show dracula"},
      {"Compare two themes", "alaja theme compare dracula nord"},
      {"Compare all themes", "alaja theme compare"}
    ]
  ]

  alias Alaja.CLI.GlobalOpts
  alias Alaja.{Config, Theme}
  alias Alaja.Components.Table, as: TableComp
  alias Alaja.Buffer

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

  # ── Dispatch ────────────────────────────────────────────────────

  defp dispatch([], global), do: help(global)
  defp dispatch(["init" | _], global), do: run_init(global)
  defp dispatch(["set"], _global), do: run_set_picker()
  defp dispatch(["set", name | _], global), do: run_set(name, global)
  defp dispatch(["list" | _], global), do: run_list(global)
  defp dispatch(["show" | names], global), do: run_show(names, global)
  defp dispatch(["compare" | names], global), do: run_compare(names, global)
  defp dispatch(["all" | _], global), do: run_all(global)
  defp dispatch([action | _], global), do: unknown_action(action, global)

  # ── init ────────────────────────────────────────────────────────

  defp run_init(_global) do
    File.mkdir_p!(Path.expand("~/.config/alaja/themes"))

    Enum.each(Alaja.Theme.templates(), &Alaja.Theme.install_template/1)
    Enum.each(Alaja.Theme.CustomTemplates.all(), &Alaja.Theme.install!/1)

    Alaja.Theme.activate(@default_theme)
    Alaja.Config.set(:theme_active, @default_theme)

    IO.puts("✓ Initialized themes. Active: #{@default_theme}")
  end

  @default_theme "catppuccin"

  # ── set (interactive picker) ───────────────────────────────────

  defp run_set_picker do
    case Theme.list() do
      [] ->
        IO.puts(:stderr, "✗ No themes found. Run `alaja theme init` first.")
        :error

      themes ->
        active = to_string(Config.get(:theme_active))
        index = Enum.find_index(themes, &(&1 == active)) || 0

        case Alaja.CLI.Picker.run(themes, "Select a theme:",
               initial_index: index,
               formatter: &format_theme_option(&1, &2 == active)
             ) do
          {:ok, name} ->
            do_activate(name)

          :cancelled ->
            IO.puts("(cancelled)")
            :ok
        end
    end
  end

  defp format_theme_option(name, is_active) do
    suffix = if is_active, do: " (active)", else: ""
    "#{name}#{suffix}"
  end

  defp do_activate(name) do
    Theme.activate(name)
    Config.set(:theme_active, name)
    IO.puts("✓ Activated theme: #{name}")
  end

  defp run_set(name, _global) do
    if name in Theme.list() do
      do_activate(name)
    else
      IO.puts(:stderr, "✗ Unknown theme: #{name}")
      IO.puts(:stderr, "  Available: #{Enum.join(Theme.list(), ", ")}")
      :error
    end
  end

  # ── list (compact table) ───────────────────────────────────────

  defp run_list(global) do
    case Theme.list() do
      [] ->
        IO.puts("  No themes found. Run `alaja theme init` first.")

      themes ->
        active = to_string(Config.get(:theme_active))
        rows = Enum.map(themes, fn name ->
          [color_swatch_for(name), name, if(name == active, do: "✓", else: "")]
        end)

        headers = ["Swatch", "Theme", "Active"]

        table_opts = [
          border: :rounded,
          padding: 1,
          color: theme_color(global),
          headers_color: [{255, 255, 255}],
          headers_effects: [:bold]
        ]

        IO.puts("")

        [headers | rows]
        |> TableComp.render(table_opts)
        |> Buffer.to_iodata()
        |> IO.iodata_to_binary()
        |> IO.write()
    end
  end

  defp color_swatch_for(theme_name) do
    case Config.load_theme(theme_name) do
      {:ok, data} ->
        case Map.get(data, "colors", %{}) do
          %{"primary" => [r, g, b]} -> color_swatch({r, g, b})
          %{"background" => [r, g, b]} -> color_swatch({r, g, b})
          _ -> "  "
        end
      _ -> "  "
    end
  end

  # ── show ────────────────────────────────────────────────────────

  defp run_show([], global), do: show_all_themes(global)

  defp run_show([name], _global) when name in ["all", "list"] do
    show_compare(Theme.list(), %{})
  end

  defp run_show([name], _global) do
    show_single_theme(name, %{})
  end

  defp run_show(names, global) do
    themes = Theme.list()

    cond do
      Enum.all?(names, &(&1 in themes)) -> show_compare(names, global)
      true -> handle_missing(names, themes)
    end
  end

  defp handle_missing(names, themes) do
    missing = Enum.reject(names, &(&1 in themes))
    IO.puts(:stderr, "✗ Unknown theme(s): #{Enum.join(missing, ", ")}")
    IO.puts(:stderr, "  Available: #{Enum.join(themes, ", ")}")
    :error
  end

  defp show_single_theme(name, _global) do
    case Config.load_theme(name) do
      {:ok, data} ->
        colors = Map.get(data, "colors", %{}) |> Enum.sort_by(fn {k, _} -> k end)

        rows =
          Enum.map(colors, fn {k, [r, g, b]} ->
            [
              color_swatch({r, g, b}),
              k,
              "##{String.upcase(Base.encode16(<<r, g, b>>))}",
              "#{r}, #{g}, #{b}"
            ]
          end)

        headers = ["Swatch", "Key", "Hex", "RGB"]

        table_opts = [
          border: :single,
          padding: 1,
          color: {255, 255, 255},
          headers_color: [{255, 255, 255}],
          headers_effects: [:bold]
        ]

        IO.puts("")
        IO.puts("  Theme: #{name}")

        [headers | rows]
        |> TableComp.render(table_opts)
        |> Buffer.to_iodata()
        |> IO.iodata_to_binary()
        |> IO.write()

      {:error, _} ->
        IO.puts(:stderr, "  Could not load theme '#{name}'.")
    end
  end

  # ── compare (with pagination) ───────────────────────────────────

  defp run_compare([], global), do: run_compare(Theme.list(), global)

  defp run_compare(names, _global) do
    themes = Enum.filter(names, &(&1 in Theme.list()))
    cond_paginate(themes)
  end

  defp cond_paginate([]) do
    IO.puts("  No themes found. Run `alaja theme init` first.")
  end

  defp cond_paginate(themes) when length(themes) > 3 do
    Alaja.CLI.Pagination.paginate(themes, per_page: 2,
      render: &show_compare(&1, %{}))
  end

  defp cond_paginate(themes) do
    show_compare(themes, %{})
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
    else
      all_keys =
        theme_data
        |> Enum.flat_map(fn {_, colors} -> Map.keys(colors) end)
        |> Enum.uniq()
        |> Enum.sort()

      headers = ["Key" | themes]
      rows =
        Enum.map(all_keys, fn key ->
          [key | Enum.map(themes, fn theme ->
            case Map.get(theme_data[theme] || %{}, key) do
              [r, g, b] -> "#{color_swatch({r, g, b})} ##{String.upcase(Base.encode16(<<r, g, b>>))}"
              _ -> "-"
            end
          end)]
        end)

      table_opts = [
        border: :rounded,
        padding: 1,
        color: {255, 255, 255},
        headers_color: [{255, 255, 255}],
        headers_effects: [:bold]
      ]

      IO.puts("")
      [headers | rows]
      |> TableComp.render(table_opts)
      |> Buffer.to_iodata()
      |> IO.iodata_to_binary()
      |> IO.write()
    end
  end

  defp show_all_themes(_global) do
    Theme.list() |> Enum.each(&show_single_theme(&1, %{}))
  end

  # ── errors / helpers ───────────────────────────────────────────

  defp unknown_action(action, _global) do
    IO.puts(:stderr, "✗ Unknown action: #{action}")
    IO.puts(:stderr, "  Actions: init, set, list, show, compare, all")
    :error
  end

  defp usage_error(hint) do
    IO.puts(:stderr, "✗ Usage: alaja theme #{hint}")
    :error
  end

  defp theme_color(%{no_color: true}), do: nil
  defp theme_color(_), do: {255, 255, 255}

  defp color_swatch({r, g, b}) do
    "\e[48;2;#{r};#{g};#{b}m    \e[0m"
  end

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: Alaja.CLI.HelpFormatter.render(@help_data, global)
end
