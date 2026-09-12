defmodule Alaja.CLI.Commands.Show.Animate do
  @moduledoc """
  `alaja animate` — Display animated spinners and indicators.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "animate", "Display animated spinners and indicators" do
    flag :type, :string, default: "spinner"
    flag :duration, :integer, default: nil
    flag :text, :string, default: nil
    flag :color, :string, default: nil
    flag :speed, :integer, default: 80
    flag :chars, :string, default: nil
    flag :colors, :string, default: nil

    run fn opts ->
      Alaja.Components.Animate.run(opts)
    end
  end
end
