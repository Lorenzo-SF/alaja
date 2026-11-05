defmodule Alaja.PoteIntegrationTest do
  @moduledoc """
  Integration tests covering the bridge between Alaja's active theme
  and Pote's `"theme:<key>"` color resolution.

  This is the regression suite for the bug where
  `alaja separator --color "theme:ternary"` ignored the user's active
  theme and always fell back to Pote's hardcoded `@default_colors`.
  """

  use ExUnit.Case

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "alaja_integration_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(tmp_dir, "themes"))

    dracula_path = Path.join([tmp_dir, "themes", "dracula.json"])

    File.write!(
      dracula_path,
      Jason.encode!(%{
        "name" => "dracula",
        "description" => "Dracula palette",
        "colors" => %{
          "primary" => [189, 147, 249],
          "ternary" => [255, 184, 108],
          "background" => [40, 42, 54]
        }
      })
    )

    System.put_env("ALAJA_THEMES_PATH", Path.join(tmp_dir, "themes"))
    Application.put_env(:alaja, :theme_active, "dracula")

    on_exit(fn ->
      System.delete_env("ALAJA_THEMES_PATH")
      Application.delete_env(:alaja, :theme_active)
      File.rm_rf!(tmp_dir)
    end)

    :ok
  end

  describe "Alaja theme resolver is registered at boot" do
    test "resolver consults Alaja.Config.lookup_theme_color/1" do
      resolver = Pote.theme_resolver()
      assert {:ok, {189, 147, 249}} = resolver.("primary")
      assert {:ok, {255, 184, 108}} = resolver.("ternary")
      assert :not_found = resolver.("missing_key")
    end
  end

  describe "Pote.parse(\"theme:<key>\") via Alaja" do
    test "resolves to active theme color, NOT Pote's hardcoded defaults" do
      # Without this bridge, Pote.get_color(:ternary) would return
      # Pote's hardcoded {255, 128, 0} (its @default_colors palette).
      # The Dracula theme has a different ternary: {255, 184, 108}.
      assert {:ok, {255, 184, 108}} = Pote.parse("theme:ternary")
    end

    test "primary resolves to the active theme's primary" do
      assert {:ok, {189, 147, 249}} = Pote.parse("theme:primary")
    end

    test "background resolves to the active theme's background" do
      assert {:ok, {40, 42, 54}} = Pote.parse("theme:background")
    end

    test "unknown theme keys return :error" do
      assert {:error, _msg} = Pote.parse("theme:not_in_dracula")
    end
  end

  describe "regression for the original bug" do
    test "theme:ternary differs from Pote.@default_colors.ternary" do
      # Pote's hardcoded @default_colors.ternary is {255, 128, 0}
      # (a more orange shade). Dracula's ternary is {255, 184, 108}
      # (warmer, lighter). If the bridge works, we get the latter.
      assert {:ok, {255, 184, 108}} = Pote.parse("theme:ternary")
      refute {:ok, {255, 128, 0}} == Pote.parse("theme:ternary")
    end
  end
end
