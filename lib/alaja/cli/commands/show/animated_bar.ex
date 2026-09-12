defmodule Alaja.CLI.Commands.Show.AnimatedBar do
  @moduledoc """
  `alaja animated-bar` — Animated progress bar.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  All parsing/argument logic lives in `Alaja.Components.AnimatedBar`.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "animated-bar", "Animated progress bar" do
    argument :value, :integer, required: false
    flag :max, :integer, default: 100
    flag :type, :string, default: "spinner"
    flag :label, :string, default: nil
    flag :width, :integer, default: 40
    flag :filled_char, :string, default: "▓"
    flag :empty_char, :string, default: "░"
    flag :filled_color, :string, default: "success"
    flag :empty_color, :string, default: "background"
    flag :animation_color, :string, default: nil
    flag :speed, :integer, default: 80
    flag :duration, :integer, default: nil
    flag :max_iterations, :integer, default: nil
    flag :show_percent, :boolean, default: true
    flag :kitt_width, :integer, default: 3
    flag :verbose, :boolean, default: false

    run fn opts ->
      Alaja.Components.AnimatedBar.run(opts)
    end
  end
end
