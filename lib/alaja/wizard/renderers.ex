defmodule Alaja.Wizard.Renderers do
  @moduledoc """
  Internal renderer implementations for `Alaja.Wizard`.

  Each renderer takes an `Alaja.Wizard.t/0` and returns an
  `Alaja.Buffer.t/0`. Renderers are pure: same input produces the
  same output.

  This module is internal — call sites should dispatch via
  `Alaja.Wizard.render/2` rather than calling these directly. The
  functions are deliberately named after the five neutral renderer
  identifiers (`:inline, :compact, :stacked, :wizard, :compact_wizard`)
  and never after any downstream brand or product.
  """

  alias Alaja.Buffer

  @doc false
  def inline(%Alaja.Wizard{}), do: Buffer.new(0, 0)

  @doc false
  def compact(%Alaja.Wizard{}), do: Buffer.new(0, 0)

  @doc false
  def stacked(%Alaja.Wizard{}), do: Buffer.new(0, 0)

  @doc false
  def wizard(%Alaja.Wizard{}), do: Buffer.new(0, 0)

  @doc false
  def compact_wizard(%Alaja.Wizard{}), do: Buffer.new(0, 0)
end