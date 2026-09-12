defmodule Alaja.CLI.Commands.Color do
  @moduledoc """
  `alaja color` — Color analysis, harmonies, conversions, and tone manipulation.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  All color logic lives in `Alaja.CLI.Color` + `Pote`.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "color", "Color analysis, harmonies, conversions, tone manipulation" do
    argument :color, :string, required: false
    flag :harmony, :string, default: nil
    flag :darken, :integer, default: nil
    flag :lighten, :integer, default: nil
    flag :lab, :boolean, default: false
    flag :xyz, :boolean, default: false
    flag :kelvin, :boolean, default: false
    flag :pantone, :boolean, default: false
    flag :contrast, :string, default: nil
    flag :wheel, :boolean, default: false

    run fn opts ->
      Alaja.CLI.Color.run_with_opts(opts)
    end
  end
end
