defmodule Alaja.CLI.Commands.Show.Gradient do
  @moduledoc """
  `alaja gradient` — Display gradient-colored text.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "gradient", "Gradient-colored text (multi-color support)" do
    argument :text, :string, required: false
    flag :from, :string, default: nil
    flag :to, :string, default: nil
    flag :colors, :string, default: nil
    flag :direction, :string, default: "left_to_right"
    flag :bg, :boolean, default: false
    flag :color, :string, default: nil

    run fn opts ->
      Alaja.Components.Gradient.render(opts)
    end
  end
end
