defmodule Alaja.Wizard do
  @moduledoc """
  Declarative multi-field form renderer for Alaja.

  A Wizard holds an ordered list of fields (name, label, type, value,
  default, hint). It does NOT run interactively — it renders to an
  `Alaja.Buffer.t/0` via one of the five neutral renderers:

      :inline           — all fields on one line, comma-separated
      :compact          — two-column table (label | value)
      :stacked          — one field per row, label above value
      :wizard           — boxed form with progress marker
      :compact_wizard   — boxed form, single-line per field

  Renderers are pure: same input, same output Buffer. Use
  `Alaja.Printer.print_raw/2` (or your own Buffer consumer) to flush.

  ## Example

      w =
        Alaja.Wizard.new()
        |> Alaja.Wizard.field(:name, :string, label: "Name", default: "alice")
        |> Alaja.Wizard.field(:age, :integer, label: "Age", default: 30)
        |> Alaja.Wizard.field(:newsletter, :boolean, label: "Subscribe?", default: true)

      Alaja.Wizard.render(w, :compact) |> Alaja.Printer.print_raw()

  See `render/2` for the full dispatcher and `field/3` for accepted
  options.
  """

  alias Alaja.{Buffer, Cell}

  @type field_type :: :string | :integer | :float | :boolean | :enum | :path | :url
  @type field :: %{
          name: atom(),
          label: String.t(),
          type: field_type(),
          value: any(),
          default: any(),
          hint: String.t() | nil,
          values: [any()] | nil
        }

  @type t :: %__MODULE__{
          fields: [field()],
          title: String.t() | nil,
          renderer: :inline | :compact | :stacked | :wizard | :compact_wizard
        }

  defstruct fields: [], title: nil, renderer: :compact

  # ─── Builder ────────────────────────────────────────────────────────

  @doc """
  Starts a new empty Wizard.

  ## Options

    - `:title` — title rendered at the top of boxed renderers
    - `:renderer` — default renderer for `render/1` (default `:compact`)
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      title: Keyword.get(opts, :title),
      renderer: Keyword.get(opts, :renderer, :compact)
    }
  end

  @doc """
  Appends a field to the wizard.

  ## Options

    - `:label`     — human-readable label (defaults to `Atom.to_string(name)`)
    - `:default`   — default value applied when `value` is unset
    - `:hint`      — small helper text shown beneath the field
    - `:values`    — for `:enum` type, the allowed atoms/strings

  The current value falls back to `:default` if `:value` is not given.
  Use `set/3` to mutate a value in-place on a wizard.
  """
  @spec field(t(), atom(), field_type(), keyword()) :: t()
  def field(%__MODULE__{} = w, name, type, opts \\ []) when is_atom(name) and is_atom(type) do
    label = Keyword.get(opts, :label, name |> Atom.to_string() |> humanize())

    field = %{
      name: name,
      label: label,
      type: type,
      value: Keyword.get(opts, :value, Keyword.get(opts, :default)),
      default: Keyword.get(opts, :default),
      hint: Keyword.get(opts, :hint),
      values: Keyword.get(opts, :values)
    }

    %{w | fields: w.fields ++ [field]}
  end

  @doc """
  Sets the value of an existing field by name.

  Raises `ArgumentError` if no field with that name exists.
  """
  @spec set(t(), atom(), any()) :: t()
  def set(%__MODULE__{fields: fields} = w, name, value) do
    case Enum.find_index(fields, &(&1.name == name)) do
      nil ->
        raise ArgumentError, "Wizard has no field named #{inspect(name)}"

      idx ->
        updated = Enum.at(fields, idx) |> Map.put(:value, value)
        %{w | fields: List.replace_at(fields, idx, updated)}
    end
  end

  # ─── Render dispatcher ──────────────────────────────────────────────

  @doc """
  Renders the wizard to an `Alaja.Buffer.t/0` using the named renderer.

  Recognised renderers: `:inline, :compact, :stacked, :wizard,
  :compact_wizard`. Any other atom raises `ArgumentError`.
  """
  @spec render(t(), :inline | :compact | :stacked | :wizard | :compact_wizard) :: Buffer.t()
  def render(w, renderer \\ nil)

  def render(%__MODULE__{} = w, nil), do: render(w, w.renderer)
  def render(%__MODULE__{} = w, :inline), do: Alaja.Wizard.Renderers.inline(w)
  def render(%__MODULE__{} = w, :compact), do: Alaja.Wizard.Renderers.compact(w)
  def render(%__MODULE__{} = w, :stacked), do: Alaja.Wizard.Renderers.stacked(w)
  def render(%__MODULE__{} = w, :wizard), do: Alaja.Wizard.Renderers.wizard(w)
  def render(%__MODULE__{} = w, :compact_wizard), do: Alaja.Wizard.Renderers.compact_wizard(w)

  def render(%__MODULE__{}, other) do
    raise ArgumentError,
          "Unknown Wizard renderer #{inspect(other)}; " <>
            "expected one of :inline, :compact, :stacked, :wizard, :compact_wizard"
  end

  # ─── Helpers ────────────────────────────────────────────────────────

  defp humanize(s) do
    s
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end