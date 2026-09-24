defmodule Alaja.CLI.Commands.Theme do
  @moduledoc """
  `alaja theme` — Manage themes (get / set / list / show / show all).
  """

  # The minimum key set every Alaja theme is expected to expose. The
  # `show` renderer uses this list to enumerate table rows even when the
  # loaded theme omits some entries — those cells then display `N/A`
  # so the user can see exactly which standard keys their theme is
  # missing.
  @required_keys ~w(
    primary secondary ternary quaternary
    success warning error info debug
    alert critical happy sad
    gradient_1 gradient_2 gradient_3 gradient_4 gradient_5 gradient_6
    background menu no_color
  )

  # Width (in cells) of the visual colour sample shown in the `muestra`
  # column. Wide enough to be obviously a colour swatch, narrow enough
  # not to dominate the rest of the table.
  @swatch_width 6

  @help_data [
    title: "Alaja Theme",
    subtitle: "Manage themes — get, set, list, show",
    usage: "alaja theme [get | set <name> | list | show <theme> | show all]",
    description: """
    Manages the active theme and the themes installed under
    `~/.config/alaja/themes`.

    `get`              — print the currently active theme name.
    `set <name>`       — activate an installed theme.
    `list`             — list installed themes and mark the active one.
    `show <theme>`     — render a colour table for one theme.
    `show all`         — render a colour table covering every required key
                         plus any custom keys defined by the active theme.

    The `show` table is built dynamically from the same format list
    that the parser understands (`Alaja.CLI.Color.formats/0`), so any
    format added to the parser automatically becomes a column here.
    """,
    options: [],
    examples: [
      {"Show the currently active theme", "alaja theme get"},
      {"Activate catppuccin", "alaja theme set catppuccin"},
      {"List installed themes", "alaja theme list"},
      {"Show the palette of one theme", "alaja theme show dracula"},
      {"Show every required key + any custom keys", "alaja theme show all"}
    ]
  ]

  alias Alaja.CLI.Color
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

  # ── Dispatch ────────────────────────────────────────────────────────────
  #
  # Each sub-command is one function head so this dispatcher stays flat
  # and under credo's cyclomatic-complexity cap.

  defp dispatch([], global), do: help(global)
  defp dispatch(["init" | _], global), do: run_init(global)
  defp dispatch(["get" | _], global), do: run_get(global)
  defp dispatch(["set"], _global), do: run_set_picker()
  defp dispatch(["set", name | _], global), do: run_set(name, global)
  defp dispatch(["list" | _], global), do: run_list(global)
  defp dispatch(["show", "all" | _], global), do: run_show_all(global)
  defp dispatch(["show", name | _], global), do: run_show(name, global)
  defp dispatch(["show" | _], _global), do: usage_error("show <theme> | show all")
  defp dispatch(["compare" | names], global), do: run_compare(names, global)
  defp dispatch([action | _], _global), do: unknown_action(action)

  defp usage_error(hint) do
    IO.puts(:stderr, "  Usage: alaja theme #{hint}")
  end

  defp unknown_action(action) do
    IO.puts(:stderr, "  alaja theme: unknown action '#{action}'")

    IO.puts(
      :stderr,
      "  Usage: alaja theme [get | set <name> | list | show <theme> | show all]"
    )
  end

  # ── `get` — print the active theme name ──────────────────────────────────

  defp run_get(_global) do
    case current_name() do
      nil ->
        IO.puts(:stderr, "  No active theme. Run `alaja theme list` to see installed.")

      name ->
        IO.puts("  #{name}")
    end
  end

  # ── `set` — activate an installed theme ────────────────────────────────

  defp run_set(name, _global) do
    case Theme.list() do
      [] ->
        IO.puts(:stderr, "  No themes found. Run `alaja theme init` first.")

      installed ->
        if name in installed do
          :ok = Theme.activate(name)
          Config.set(:theme_active, name)
          IO.puts("  \e[38;2;72;187;120m✓\e[0m Theme set to '#{name}'")
        else
          IO.puts(:stderr, "  Theme '#{name}' not found.")
          IO.puts(:stderr, "  Available themes (run `alaja theme list` for full output):")
          Enum.each(installed, &IO.puts(:stderr, "    • #{&1}"))
        end
    end
  end

  # ── `list` — list installed themes, mark the active one ─────────────────

  defp run_list(_global) do
    case Theme.list() do
      [] ->
        IO.puts(:stderr, "  No themes found. Run `alaja theme init` first.")

      themes ->
        IO.puts("")
        Enum.each(themes, &print_theme_line(&1, current_name()))
        IO.puts("")
    end
  end

  defp print_theme_line(name, active) do
    marker =
      if name == active, do: "  \e[38;2;72;187;120m✓\e[0m ← active", else: ""

    IO.puts("  • #{name}#{marker}")
  end

  # ── `show <theme>` — colour table for one theme ─────────────────────────

  defp run_show(name, _global) do
    case load_theme(name) do
      :not_found ->
        IO.puts(:stderr, "  Theme '#{name}' not found. Run `alaja theme list` to see available.")
        print_suggestion(name)

      colors ->
        print_color_table(colors, show_keys(name, colors))
    end
  end

  # ── `show all` — colour table for every required + custom key ───────────

  defp run_show_all(_global) do
    case load_theme(current_name()) do
      :not_found ->
        IO.puts(:stderr, "  No active theme to display.")

      :missing ->
        IO.puts(
          :stderr,
          "  Active theme has no colour data. Run `alaja theme init` then re-activate."
        )

      colors ->
        print_color_table(colors, show_keys(nil, colors))
    end
  end

  # The list of keys a `show` run should render, in the order
  # the rows appear in the table. The leading name slot is only
  # relevant for `show <theme>` (it's the "what theme is this?"
  # row at the top) — `show all` passes `nil` and just shows the
  # required + custom keys.
  #
  # Required keys come first in their canonical order, then any
  # extra keys the theme defines that aren't part of the required
  # set, sorted alphabetically for stable output across runs.
  defp show_keys(name, colors) do
    extra =
      colors
      |> Map.keys()
      |> Enum.reject(&(&1 in @required_keys))
      |> Enum.sort()

    required = if(name, do: [name | @required_keys], else: @required_keys)
    required ++ extra
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  # Loads a theme's colour map from the on-disk JSON, falling back to the
  # in-memory cache maintained by `Alaja.Theme` if the file isn't there
  # yet but the theme is registered.
  defp load_theme(name) when is_binary(name) do
    case Config.load_theme(name) do
      {:ok, data} ->
        data
        |> Map.get("colors", %{})
        |> normalise_colors()

      {:error, _} ->
        :not_found
    end
  end

  defp load_theme(nil), do: :missing

  # Pote's bundled templates and `install!/1` store colours as
  # `[r, g, b]` arrays, but a theme JSON can hold any colour format
  # `Alaja.CLI.Color.parse/1` understands (`rgb:R,G,B`, `#hex`,
  # `hex:...`, named colours like `"red"`, `hsl:H,S,L`, etc).
  # Route everything through the parser so the on-disk format is
  # decoupled from the in-memory representation. Returns `nil` when
  # the value can't be parsed, which the renderer turns into the dim
  # `-` placeholder so the row stays informative rather than
  # silently dropped.
  defp normalise_colors(%{} = colors) do
    Map.new(colors, fn {k, v} -> {k, normalise_color(v)} end)
  end

  defp normalise_color([r, g, b]) when is_integer(r) and is_integer(g) and is_integer(b) do
    from_color("rgb:#{r},#{g},#{b}")
  end

  defp normalise_color(value) when is_binary(value), do: from_color(value)

  defp normalise_color(_), do: nil

  defp from_color(input) do
    case Color.parse(input) do
      {:ok, rgb} -> rgb
      _ -> nil
    end
  end

  # Pulls the current theme name from the application env. Pote always
  # stores it as a string in `:theme_active`; we fall back to the
  # first installed theme if env is unset, mirroring what `Alaja.Theme`
  # itself does.
  defp current_name do
    case Config.get(:theme_active) do
      nil -> Theme.list() |> List.first()
      name when is_binary(name) -> name
      name when is_atom(name) -> Atom.to_string(name)
    end
  end

  # Fuzzy "did you mean" using trivial prefix + edit-distance, so a
  # `theme show dracula` typo gives the user something concrete to try.
  defp print_suggestion(name) do
    candidates = Theme.list()

    suggestion =
      Enum.find(candidates, fn c ->
        String.jaro_distance(name, c) > 0.85 or String.starts_with?(c, String.slice(name, 0, 3))
      end)

    if suggestion do
      IO.puts(:stderr, "  Did you mean `alaja theme show #{suggestion}`?")
    end
  end

  # ── Colour table renderer ───────────────────────────────────────────────

  # Builds and prints the colour table. Columns are:
  #
  #   1. `key` (e.g. `theme:primary`)            — fixed
  #   2. `muestra` (coloured text on the colour) — fixed swatch
  #   3. one column per format in `output_formats/0`,
  #      serialised via `Color.serialize/2`. Adding a new format
  #      automatically adds a new column here.
  #
  # Missing colours render as `-` (swatch) and `-` in every code
  # column, so the user can spot which keys their theme is missing
  # at a glance.
  defp print_color_table(colors, keys) do
    formats = Color.output_formats()
    headers = ["key", "muestra"] ++ Enum.map(formats, &String.upcase/1)
    rows = Enum.map(keys, &row_for_key(&1, colors, formats))

    Alaja.Components.Table.print(
      headers: headers,
      rows: rows,
      table_border: :rounded,
      border_color: :cyan,
      rows_2_color: [:white, :default | List.duplicate(:default, length(formats))],
      table_align: :left
    )
  end

  # Each row in the table is keyed by the form the parser accepts on
  # the CLI (i.e. `theme:<key>`). That makes the output copy-pasteable:
  # users can paste `theme:primary` back into `--color theme:primary`
  # to set the same colour elsewhere.
  defp row_for_key(key, colors, formats) do
    theme_key = if String.starts_with?(key, "theme:"), do: key, else: "theme:#{key}"
    rgb = Map.get(colors, String.replace_prefix(theme_key, "theme:", ""))

    [theme_key, render_swatch(rgb)] ++ render_code_cells(rgb, formats)
  end

  # Renders the visual colour preview: 6 cells of background colour
  # if known, otherwise a thin "-" placeholder.
  defp render_swatch(nil), do: dim("-")

  defp render_swatch({r, g, b}) do
    sample = String.duplicate(" ", @swatch_width)
    "\e[48;2;#{r};#{g};#{b}m#{sample}\e[0m"
  end

  defp render_code_cells(nil, formats), do: List.duplicate(dim("-"), length(formats))

  defp render_code_cells(rgb, formats) do
    Enum.map(formats, &Color.serialize(rgb, &1))
  end

  defp dim(text), do: "\e[2m#{text}\e[0m"

  # ── iter-059 additions ──────────────────────────────────────────────────
  # `init`  — install templates + activate default. Alias of
  #           `Alaja.Theme.Bootstrap.ensure_installed/0` for users who
  #           prefer the explicit `theme init` verb over the implicit
  #           bootstrap-on-first-use path.
  # `set`   — when called with no args, opens an interactive picker
  #           (Alaja.CLI.Picker) with arrow-key navigation.
  # `compare` — side-by-side render of multiple themes; paginates > 3.
  # `color_swatch_for` — small inline swatch used in the list/compare
  #           tables. Reads from the theme JSON on disk; falls back to
  #           two spaces when the theme isn't loadable.

  defp run_init(_global) do
    Alaja.Theme.Bootstrap.ensure_installed()

    active =
      case Alaja.Config.get(:theme_active) do
        nil -> "default"
        name -> to_string(name)
      end

    IO.puts("✓ Initialized themes. Active: #{active}")
  end

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

  defp run_compare(names, global) when is_list(names) do
    names =
      case names do
        [] -> Theme.list()
        list -> list
      end

    themes = Enum.filter(names, &(&1 in Theme.list()))

    if themes == [] do
      IO.puts("  No themes found. Run `alaja theme init` first.")
    else
      paginate_compare(themes, global)
    end
  end

  # Side-by-side compare. For > 3 themes we chunk in groups of 2 so
  # each table stays readable; between groups we wait for a key so
  # the user has time to inspect each chunk.
  defp paginate_compare(themes, global) do
    chunks = Enum.chunk_every(themes, 2)
    last_chunk = List.last(chunks)

    Enum.each(chunks, fn chunk ->
      show_compare(chunk, global)
      if chunk != last_chunk, do: wait_for_key()
    end)
  end

  defp wait_for_key do
    IO.write("\n  --- press any key for next group ---")
    _ = IO.read(:stdio, 1)
    IO.puts("")
  end

  defp show_compare([], _), do: :ok

  defp show_compare(themes, _global) do
    theme_data =
      Enum.reduce(themes, %{}, fn name, acc ->
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
          [key | Enum.map(themes, fn theme -> format_compare_cell(theme, theme_data, key) end)]
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
      |> Alaja.Components.Table.render(table_opts)
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()
      |> IO.write()
    end
  end

  defp format_compare_cell(theme, theme_data, key) do
    case Map.get(theme_data[theme] || %{}, key) do
      [r, g, b] -> "#{color_swatch({r, g, b})} ##{String.upcase(Base.encode16(<<r, g, b>>))}"
      _ -> "-"
    end
  end

  defp color_swatch({r, g, b}) do
    "\e[48;2;#{r};#{g};#{b}m    \e[0m"
  end

  # ── Help ────────────────────────────────────────────────────────────────

  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: Alaja.CLI.HelpFormatter.render(@help_data, global)
end
