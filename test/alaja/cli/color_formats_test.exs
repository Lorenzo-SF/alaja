defmodule Alaja.CLI.ColorFormatsTest do
  use ExUnit.Case, async: true

  alias Alaja.CLI.Color

  describe "formats/0" do
    test "lists all supported input formats" do
      formats = Color.formats()

      assert is_list(formats)

      for required <- ~w(rgb argb hex xterm cmyk hsl hsv hwb theme) do
        assert required in formats, "missing format: #{required}"
      end
    end
  end

  describe "output_formats/0" do
    test "is formats/0 minus `theme`" do
      assert Color.output_formats() == Enum.reject(Color.formats(), &(&1 == "theme"))
    end

    test "does not include theme (which is a source, not a serialisation target)" do
      refute "theme" in Color.output_formats()
    end
  end

  describe "serialize/2 — RGB → \"<format>:<code>\"" do
    test "rgb roundtrips through parse/1" do
      rgb = {200, 100, 50}
      assert Color.serialize(rgb, "rgb") == "rgb:200,100,50"
    end

    test "argb assumes opaque alpha=255" do
      assert Color.serialize({255, 0, 0}, "argb") == "argb:255,255,0,0"
    end

    test "hex is upper-case without the leading #" do
      assert Color.serialize({255, 0, 0}, "hex") == "hex:FF0000"
    end

    test "xterm returns an integer index" do
      assert Color.serialize({255, 0, 0}, "xterm") == "xterm:196"
    end

    test "cmyk, hsv, hsl, hwb use percentages or counts" do
      r = {255, 0, 0}
      assert Color.serialize(r, "cmyk") == "cmyk:0,100,100,0"
      assert Color.serialize(r, "hsv") == "hsv:0,100,100"
      assert Color.serialize(r, "hsl") == "hsl:0,100,50"
      assert Color.serialize(r, "hwb") =~ ~r/^hwb:\d+,\d+,\d+$/
    end

    test "roundtrips exactly for lossless formats" do
      # `rgb`, `argb`, `hex` are *lossless* — the wire code already names
      # the channels directly, so the parsed RGB equals the original
      # bit-for-bit.
      rgb = {200, 100, 50}

      for format <- ~w(rgb argb hex) do
        code = Color.serialize(rgb, format)
        assert {:ok, ^rgb} = Color.parse(code), "roundtrip failed for #{format}: #{code}"
      end
    end

    test "roundtrips within ±5 per channel for lossy formats" do
      # `xterm`, `cmyk`, `hsv`, `hsl`, `hwb` go through lossy conversions
      # (xterm: 256-colour palette; the rest: integer-rounded colour
      # space). The contract is "visually indistinguishable", not
      # bit-for-bit identical.
      rgb = {255, 0, 0}

      for format <- ~w(xterm cmyk hsv hsl hwb) do
        code = Color.serialize(rgb, format)
        {:ok, back} = Color.parse(code)
        assert_almost(back, rgb, format, tolerance: 5)
      end
    end

    defp assert_almost({r1, g1, b1}, {r2, g2, b2}, format, opts) do
      tol = Keyword.get(opts, :tolerance, 1)

      assert abs(r1 - r2) <= tol, "r drift in #{format}: #{r1} vs #{r2}"
      assert abs(g1 - g2) <= tol, "g drift in #{format}: #{g1} vs #{g2}"
      assert abs(b1 - b2) <= tol, "b drift in #{format}: #{b1} vs #{b2}"
    end
  end

  describe "theme:<key> parser bug fix (custom theme keys)" do
    test "parses theme:<key> for a STANDARD key against the active theme" do
      # The active theme is whatever the test env set up; we just need
      # the parser to return SOME non-white RGB for a key present in
      # Pote's hardcoded `@default_colors`, so we don't depend on the
      # theme store here.
      assert {:ok, rgb} = Color.parse("theme:primary")
      refute rgb == {255, 255, 255}
    end

    test "parses theme:<key> for a CUSTOM key present in the active theme" do
      # Install a synthetic theme with one of the 19 required keys
      # (primary) plus one custom key (my_brand) so the registry
      # exposes it without falling through to Pote's @default_colors.
      original_active = Application.get_env(:alaja, :theme_active)

      custom_theme = %Pote.Theme.Theme{
        name: "test_custom_keys",
        description: "Synthetic theme with a custom key for parser coverage.",
        colors: %{
          "primary" => {255, 0, 0},
          "my_brand" => {100, 200, 50},
          "secondary" => {0, 255, 0},
          "ternary" => {0, 0, 255},
          "quaternary" => {128, 128, 128},
          "success" => {0, 255, 0},
          "warning" => {255, 255, 0},
          "error" => {255, 0, 0},
          "info" => {0, 255, 255},
          "debug" => {100, 100, 100},
          "alert" => {255, 165, 0},
          "critical" => {255, 0, 0},
          "happy" => {255, 192, 203},
          "sad" => {0, 0, 128},
          "gradient_1" => {255, 0, 0},
          "gradient_2" => {255, 127, 0},
          "gradient_3" => {255, 255, 0},
          "gradient_4" => {0, 255, 0},
          "gradient_5" => {0, 0, 255},
          "gradient_6" => {127, 0, 255},
          "background" => {0, 0, 0},
          "menu" => {255, 255, 255},
          "no_color" => {255, 255, 255}
        }
      }

      try do
        :ok = Alaja.Theme.install!(custom_theme)
        :ok = Alaja.Theme.activate("test_custom_keys")

        assert {:ok, {100, 200, 50}} = Color.parse("theme:my_brand"),
               "parser fell through to the {255,255,255} fallback for the custom key"

        # And the required keys resolve against the installed theme, not
        # the global @default_colors map.
        assert {:ok, {255, 0, 0}} = Color.parse("theme:primary")
      after
        Application.put_env(:alaja, :theme_active, original_active)
      end
    end
  end
end
