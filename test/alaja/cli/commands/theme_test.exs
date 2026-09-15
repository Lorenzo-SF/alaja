defmodule Alaja.CLI.Commands.ThemeTest do
  @moduledoc """
  Tests for `alaja theme` subcommands: `get`, `set`, `list`, `show`,
  `show all`, and the default (`alaja theme` → help).

  Exercises the redesigned dispatcher with both happy paths and
  diagnostic failures (unknown theme, missing theme, no active theme).
  """

  use ExUnit.Case, async: false

  import ExUnit.CaptureIO, only: [capture_io: 1, capture_io: 2]

  alias Alaja.CLI.Commands.Theme, as: ThemeCmd
  alias Alaja.{Config, Theme}

  # We never want a stale `~/.config/alaja/themes` directory from a
  # developer machine to leak into the "no themes installed" tests, and
  # we never want our tests to actually mutate the user's real theme
  # directory. Every test that touches the theme store uses
  # `with_themes_dir/2` to redirect `ALAJA_THEMES_PATH` to a
  # tmp dir that is cleaned up afterwards.
  setup do
    original_env = System.get_env("ALAJA_THEMES_PATH")
    original_conf = System.get_env("ALAJA_THEMES_PATH")

    on_exit(fn ->
      System.delete_env("ALAJA_THEMES_PATH")
      if original_env, do: System.put_env("ALAJA_THEMES_PATH", original_env)
      if original_conf, do: Application.delete_env(:alaja, :__conf_loaded__)
    end)

    :ok
  end

  # ExUnit's `capture_io/1` only captures `:stdout`. Some of our
  # commands write to `:stderr` (diagnostic errors) so the test
  # helpers below expose both forms and let each call site pick the
  # right one. Keep them local to this module so tests stay readable.
  defp capture_stdout(fun), do: ExUnit.CaptureIO.capture_io(fun)
  defp capture_stderr(fun), do: ExUnit.CaptureIO.capture_io(:standard_error, fun)

  # ── `alaja theme` (no args) — show help ──────────────────────────────────

  test "alaja theme with no args prints help" do
    output = capture_stdout(fn -> ThemeCmd.run([]) end)

    assert output =~ "USAGE"
    assert output =~ "alaja theme [get | set <name> | list | show <theme> | show all]"
  end

  test "alaja theme --help prints help" do
    output = capture_stdout(fn -> ThemeCmd.run(["--help"]) end)

    assert output =~ "Manage themes"
    assert output =~ "USAGE"
  end

  test "alaja theme with an unknown subcommand prints usage" do
    output =
      capture_stderr(fn ->
        try do
          ThemeCmd.run(["bogus"])
        catch
          :exit, status -> flunk("expected graceful message, got exit #{inspect(status)}")
        end
      end)

    assert output =~ "alaja theme: unknown action 'bogus'"
    assert output =~ "Usage:"
  end

  # ── `get` — read the active theme ───────────────────────────────────────

  describe "get" do
    test "prints the active theme name when one is set" do
      Application.put_env(:alaja, :theme_active, "catppuccin")

      output = capture_stdout(fn -> ThemeCmd.run(["get"]) end)

      assert output =~ "catppuccin"
    end

    test "falls back to the first installed theme when nothing is set" do
      with_themes_dir(fn ->
        Application.delete_env(:alaja, :theme_active)
        write_theme_json("default", %{"primary" => {1, 2, 3}})

        output = capture_stdout(fn -> ThemeCmd.run(["get"]) end)

        assert output =~ "default"
      end)
    end
  end

  # ── `set` — activate a theme ─────────────────────────────────────────────

  describe "set" do
    test "activates an installed theme and persists it" do
      with_themes_dir(fn ->
        write_theme_json("dracula", %{"primary" => {200, 50, 200}})

        output = capture_stdout(fn -> ThemeCmd.run(["set", "dracula"]) end)

        assert output =~ "Theme set to 'dracula'"
        assert Application.get_env(:alaja, :theme_active) == "dracula"
      end)
    end

    test "rejects an unknown theme and prints the available list" do
      with_themes_dir(fn ->
        write_theme_json("dracula", %{"primary" => {1, 2, 3}})
        write_theme_json("nord", %{"primary" => {4, 5, 6}})

        output =
          capture_stderr(fn ->
            ThemeCmd.run(["set", "no-such-theme"])
          end)

        assert output =~ "Theme 'no-such-theme' not found."
        assert output =~ "dracula"
        assert output =~ "nord"
      end)
    end

    test "with no installed themes prints a helpful error" do
      with_themes_dir(fn ->
        output =
          capture_stderr(fn ->
            ThemeCmd.run(["set", "anything"])
          end)

        assert output =~ "No themes found"
        assert output =~ "alaja theme init"
      end)
    end
  end

  # ── `list` — list installed themes ───────────────────────────────────────

  describe "list" do
    test "prints every installed theme and marks the active one" do
      with_themes_dir(fn ->
        write_theme_json("alpha", %{"primary" => {1, 0, 0}})
        write_theme_json("beta", %{"primary" => {0, 1, 0}})
        Application.put_env(:alaja, :theme_active, "beta")

        output = capture_stdout(fn -> ThemeCmd.run(["list"]) end)

        assert output =~ "• alpha"
        assert output =~ "• beta"
        # The active marker is the only place we paint a coloured ✓
        # next to a name.
        assert output =~ "✓"
        assert output =~ "← active"
      end)
    end
  end

  # ── `show <theme>` — colour table for one theme ──────────────────────────

  describe "show <theme>" do
    test "renders a table with the required keys and every output_format column" do
      with_themes_dir(fn ->
        write_theme_json("dracula", dracula_palette())

        output = capture_stdout(fn -> ThemeCmd.run(["show", "dracula"]) end)

        # All the required keys appear in the table
        for key <- required_keys() do
          assert output =~ "theme:#{key}", "missing key column: theme:#{key}"
        end

        # Headers for the dynamic colour-format columns are upper-cased
        # versions of every format in `Color.output_formats/0`.
        for format <- Alaja.CLI.Color.output_formats() do
          assert output =~ String.upcase(format),
                 "missing format column header: #{String.upcase(format)}"
        end

        # The `muestra` column header always exists.
        assert output =~ "muestra"
      end)
    end

    test "renders custom keys present in the theme (not only the required 19)" do
      # `catppuccin_macchiato`-style theme: it has the 19 required
      # keys plus the catppuccin flavour colours (`surface0/1/2`,
      # `overlay0/1/2`, etc). Both classes should appear in the
      # table — required first, customs after, alphabetically.
      with_themes_dir(fn ->
        base = dracula_palette()
        extra = %{"surface0" => {54, 58, 79}, "surface1" => {73, 77, 100}, "surface2" => {91, 96, 120}}

        write_theme_json("catppuccin_macchiato", Map.merge(base, extra))

        output = capture_stdout(fn -> ThemeCmd.run(["show", "catppuccin_macchiato"]) end)

        # The required keys still appear.
        assert output =~ "theme:primary"
        assert output =~ "theme:background"

        # The three custom keys appear with their full RGB + table row.
        assert output =~ "theme:surface0"
        assert output =~ "theme:surface1"
        assert output =~ "theme:surface2"

        # And the wire code for each is rendered (lossless formats only).
        assert output =~ "rgb:54,58,79"
        assert output =~ "rgb:73,77,100"
        assert output =~ "rgb:91,96,120"
      end)
    end

    test "renders rows for arbitrary keys with mixed colour formats in the JSON" do
      # The whole point of the redesign was "any theme with any keys,
      # while the colour is parseable". So we exercise two things at
      # once:
      #   1. arbitrary key names that don't appear in `@required_keys`
      #      (`maroon`, `crust`, `mauve`, … — catppuccin flavour names).
      #   2. colour values stored in every format `Color.parse/1`
      #      understands, plus one invalid value that must render as
      #      N/A (so the renderer must not silently drop the row).
      with_themes_dir(fn ->
        write_raw_theme_json(
          "mixed_flavour",
          Map.merge(dracula_palette(), %{
            "maroon" => [224, 187, 228],
            "crust" => "#16131d",
            "mauve" => "b4befe",
            "red" => "red",
            "teal" => "rgb:30,194,178"
          })
          |> Map.put("broken_key", "not-a-real-colour")
        )

        output = capture_stdout(fn -> ThemeCmd.run(["show", "mixed_flavour"]) end)

        # All six custom keys appear, regardless of their colour format.
        for key <- ["maroon", "crust", "mauve", "red", "teal", "broken_key"] do
          assert output =~ "theme:#{key}",
                 "key #{key} missing from the rendered table"
        end

        # Lossless wire codes are emitted for the parseable ones.
        assert output =~ "rgb:224,187,228"  # maroon
        assert output =~ "rgb:30,194,178"   # teal

        # The invalid value's row is still drawn (and its cells are
        # the dim `-` placeholder) rather than crashing or being
        # silently omitted.
        broken_line =
          output
          |> String.split("\n", trim: true)
          |> Enum.find(&(&1 =~ "theme:broken_key"))

        assert broken_line, "row for broken_key not rendered"
        # Every code-format column in that row must be the dim
        # placeholder, not garbage.
        broken_placeholders = Regex.scan(~r/\e\[2m-\e\[0m/, broken_line)
        assert length(broken_placeholders) >= 8,
               "expected dim '-' placeholders for broken_key, got #{inspect(broken_line)}"
      end)
    end

    test "renders N/A placeholders for missing keys" do
      # Theme that only exposes `primary` — the 18 other required keys
      # should render their code cells as a dim `-`.
      with_themes_dir(fn ->
        write_theme_json("minimal", %{"primary" => {1, 2, 3}})

        output = capture_stdout(fn -> ThemeCmd.run(["show", "minimal"]) end)

        for key <- required_keys() -- ["primary"] do
          # Take the section of output between the `theme:<key>` row
          # opener and the closing border row — easier than parsing
          # cells, which is brittle when the table splits cells with
          # coloured ANSI padding.
          line =
            output
            |> String.split("\n", trim: true)
            |> Enum.find(&(&1 =~ "theme:#{key}"))

          assert line,
                 "no output row found for key #{key} — full output was:\n#{output}"

          # Every code-format column after the swatch should be the
          # dim `-` placeholder.
          placeholders = Regex.scan(~r/\e\[2m-\e\[0m/, line)
          assert length(placeholders) >= 8,
                 "expected at least 8 dim '-' cells in row for #{key}, got #{length(placeholders)}: #{inspect(line)}"
        end
      end)
    end

    test "rejects an unknown theme and suggests a close match" do
      with_themes_dir(fn ->
        write_theme_json("dracula", %{"primary" => {1, 2, 3}})

        output =
          capture_stderr(fn ->
            ThemeCmd.run(["show", "drcual"])
          end)

        assert output =~ "Theme 'drcual' not found"
        assert output =~ "Did you mean `alaja theme show dracula`?"
      end)
    end
  end

  # ── `show all` — colour table for the active theme's every key ───────────

  describe "show all" do
    test "renders the required keys plus any custom keys present in the active theme" do
      with_themes_dir(fn ->
        # A theme with `my_brand` on top of the 19 required keys.
        base =
          dracula_palette()
          |> Map.merge(%{
            "my_brand" => {200, 100, 50},
            "other_custom" => {100, 150, 200}
          })

        write_theme_json("custom_rich", base)
        Application.put_env(:alaja, :theme_active, "custom_rich")

        output = capture_stdout(fn -> ThemeCmd.run(["show", "all"]) end)

        assert output =~ "theme:my_brand"
        assert output =~ "theme:other_custom"
        # Required keys still get their slots.
        assert output =~ "theme:primary"
      end)
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  # The same 19-entry list the command uses internally. Re-stated in
  # the test so a divergence between the command's `@required_keys`
  # and this test list fails loudly (instead of silently passing because
  # both lists happen to be in sync).
  defp required_keys do
    ~w(primary secondary ternary quaternary
       success warning error info debug
       alert critical happy sad
       gradient_1 gradient_2 gradient_3 gradient_4 gradient_5 gradient_6
       background menu no_color)
  end

  # A representative 19-key palette for the dracula theme.
  # Centralised so individual tests don't need to spell out all 19
  # entries repeatedly.
  defp dracula_palette do
    %{
      "primary" => {189, 147, 249},
      "secondary" => {80, 250, 123},
      "ternary" => {255, 184, 108},
      "quaternary" => {139, 233, 253},
      "success" => {80, 250, 123},
      "warning" => {241, 250, 140},
      "error" => {255, 110, 103},
      "info" => {139, 233, 253},
      "debug" => {98, 114, 164},
      "alert" => {255, 110, 103},
      "critical" => {255, 110, 103},
      "happy" => {255, 184, 108},
      "sad" => {98, 114, 164},
      "gradient_1" => {255, 110, 103},
      "gradient_2" => {255, 184, 108},
      "gradient_3" => {241, 250, 140},
      "gradient_4" => {80, 250, 123},
      "gradient_5" => {139, 233, 253},
      "gradient_6" => {189, 147, 249},
      "background" => {40, 42, 54},
      "menu" => {248, 248, 242},
      "no_color" => {248, 248, 242}
    }
  end

  # Redirects `ALAJA_THEMES_PATH` to a fresh tmp dir for the duration
  # of `fun`, then restores. Returns whatever `fun` returns.
  defp with_themes_dir(fun) do
    dir = Path.join(System.tmp_dir!(), "alaja_test_themes_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    System.put_env("ALAJA_THEMES_PATH", dir)

    try do
      fun.()
    after
      File.rm_rf!(dir)
    end
  end

  defp write_theme_json(name, colors) do
    theme = %Pote.Theme.Theme{name: name, description: "test", colors: colors}

    :ok =
      Theme.install!(theme)
  end

  # Writes a theme JSON directly to disk under `ALAJA_THEMES_PATH`,
  # bypassing `Theme.install!/1` so we can round-trip colour values
  # in formats other than `[r,g,b]` (Pote's `save_theme/2` only
  # serialises arrays). This is what makes the `mixed colour
  # formats` test possible.
  defp write_raw_theme_json(name, colors) do
    # Jason can't encode tuples, so flatten the RGB values to
    # `[r, g, b]` lists before serialising. That's also what
    # `Config.load_theme/1` expects to receive back from the JSON.
    json_colours = Map.new(colors, fn {k, v} -> {k, rgb_tuple_to_list(v)} end)

    json =
      Jason.encode!(%{"name" => name, "description" => "test", "colors" => json_colours})

    path = Path.join([System.get_env("ALAJA_THEMES_PATH"), "#{name}.json"])
    File.write!(path, json)
  end

  defp rgb_tuple_to_list({r, g, b}), do: [r, g, b]
  defp rgb_tuple_to_list(other), do: other
end
