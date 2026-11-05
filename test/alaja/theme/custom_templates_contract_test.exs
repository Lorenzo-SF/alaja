defmodule Alaja.Theme.CustomTemplatesContractTest do
  use ExUnit.Case, async: true

  alias Alaja.Theme.CustomTemplates
  alias Alaja.Theme.RequiredKeys

  test "every CustomTemplate satisfies the contract" do
    for theme <- CustomTemplates.all() do
      assert RequiredKeys.valid?(theme.colors),
             "CustomTemplate #{theme.name} is missing required keys: " <>
               inspect(RequiredKeys.missing(theme.colors))
    end
  end

  test "every CustomTemplate has a non-empty name and description" do
    for theme <- CustomTemplates.all() do
      assert is_binary(theme.name) and theme.name != ""
      assert is_binary(theme.description) and theme.description != ""
    end
  end

  test "Catppuccin variants expose both alaja keys AND catppuccin palette keys" do
    catppuccin_palette_keys = [
      "rosewater",
      "flamingo",
      "pink",
      "mauve",
      "red",
      "maroon",
      "peach",
      "yellow",
      "green",
      "teal",
      "sky",
      "sapphire",
      "blue",
      "lavender"
    ]

    # Only the 4 catppuccin variants (mocha/frappe/latte/macchiato) use
    # the catppuccin palette naming — `catppuccin` (the default) uses
    # the alaja schema.
    variants =
      Enum.filter(CustomTemplates.all(), fn theme ->
        String.starts_with?(theme.name, "catppuccin_") or
          theme.name == "catppuccin_macchiato" or
          theme.name == "catppuccin_mocha" or
          theme.name == "catppuccin_frappe" or
          theme.name == "catppuccin_latte"
      end)

    assert length(variants) == 4,
           "expected 4 catppuccin variants but found #{length(variants)}"

    for theme <- variants do
      for key <- catppuccin_palette_keys do
        assert Map.has_key?(theme.colors, key),
               "#{theme.name} should keep the catppuccin key #{key} (lookups via theme:<key> rely on it)"
      end

      assert RequiredKeys.valid?(theme.colors),
             "#{theme.name} must also include all alaja contract keys"
    end
  end
end
