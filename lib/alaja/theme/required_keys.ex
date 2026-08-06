defmodule Alaja.Theme.RequiredKeys do
  @moduledoc """
  Contract for Alaja theme JSON files.

  Every theme installed under `~/.config/alaja/themes/*.json` must
  satisfy this contract:

    * It **MUST** contain every key in `@required/0`.
    * It **MAY** contain additional keys (themes can be extended).
    * Extra keys are looked up by name (`theme:<key>`) by anyone who
      asks; alaja itself only consumes the required keys.
    * A theme that violates the contract is installed on disk but is
      rejected at activation time — its missing keys fall back to
      `nil` (no colour), so the affected components paint without
      colour instead of crashing.

  ## Why a contract

  Themes ship as JSON files from multiple sources (Pote built-ins,
  Alaja custom templates, third-party contributions, user-edited
  files). Without a contract, a theme can use any key naming scheme
  (catppuccin palette, gruvbox, custom…) and components that ask for
  `theme:primary` will get `nil` and render colourless.

  The contract is intentionally permissive on extras (so users can
  extend with their own keys) and strict on the minimum.

  ## Adding a new required key

  Add the atom to `@required/0` and update every template in
  `Pote.Theme.Templates` and `Alaja.Theme.CustomTemplates`. The
  `theme init` flow + the contract test (`test/alaja/theme/
  required_keys_test.exs`) will catch any drift.

  ## Adding a new template

  It must include all 22 keys in `@required/0`. Extra keys are
  allowed. Run `mix test test/alaja/theme/` to verify.
  """

  @moduledoc section: :contracts

  @type key :: String.t()

  @doc "List of required theme keys (alphabetical)."
  @spec required() :: [key()]
  def required do
    [
      "alert",
      "background",
      "critical",
      "debug",
      "error",
      "gradient_1",
      "gradient_2",
      "gradient_3",
      "gradient_4",
      "gradient_5",
      "gradient_6",
      "happy",
      "info",
      "menu",
      "no_color",
      "primary",
      "quaternary",
      "sad",
      "secondary",
      "success",
      "ternary",
      "warning"
    ]
  end

  @doc "Number of required keys."
  @spec size() :: non_neg_integer()
  def size, do: length(required())

  @doc """
  Returns the keys missing from `colors`.

      iex> Alaja.Theme.RequiredKeys.missing(%{})
      ["alert", "background", ...]
      iex> Alaja.Theme.RequiredKeys.missing(%{"primary" => {0, 0, 0}, "alert" => {1, 2, 3}})
      ["background", ...]
  """
  @spec missing(%{optional(key()) => term()}) :: [key()]
  def missing(colors) when is_map(colors) do
    required() -- Map.keys(colors)
  end

  @doc """
  Returns `:ok` if `colors` contains every required key, otherwise
  `{:error, missing_keys}`.
  """
  @spec validate(%{optional(key()) => term()}) :: :ok | {:error, [key()]}
  def validate(colors) when is_map(colors) do
    case missing(colors) do
      [] -> :ok
      list -> {:error, list}
    end
  end

  @doc """
  Returns `true` if `colors` satisfies the contract.
  """
  @spec valid?(%{optional(key()) => term()}) :: boolean()
  def valid?(colors), do: validate(colors) == :ok

  @doc """
  Returns a `name`-keyed map of `colors` augmented with white fallbacks
  (`{255, 255, 255}`) for every missing required key, plus an
  `extra` list of keys that are not in `@required/0`.

  Used at activation time when a user-installed theme is incomplete —
  the theme stays usable (no crash) but the missing colours paint
  white instead of disappearing entirely.
  """
  @spec fill(%{optional(key()) => term()}) :: %{
          required(key()) => term(),
          optional(:__extra__) => [key()],
          optional(:__missing__) => [key()]
        }
  def fill(colors) when is_map(colors) do
    missing_keys = missing(colors)

    filled =
      Enum.reduce(required(), %{}, fn key, acc ->
        Map.put(acc, key, Map.get(colors, key, {255, 255, 255}))
      end)

    extras =
      colors
      |> Map.keys()
      |> Kernel.--(required())

    filled
    |> Map.merge(colors)
    |> Map.put(:__extra__, extras)
    |> Map.put(:__missing__, missing_keys)
  end
end