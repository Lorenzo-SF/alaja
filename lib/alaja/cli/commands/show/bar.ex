defmodule Alaja.CLI.Commands.Show.Bar do
  @moduledoc """
  `alaja bar` — Display progress bars.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  All parsing lives in `Alaja.Components.Bar` (the back).
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "bar", "Display a progress bar" do
    argument :value, :integer, required: true
    flag :max, :integer, default: 100
    flag :label, :string, default: nil
    flag :width, :integer, default: 40
    flag :filled_char, :string, default: "▓"
    flag :empty_char, :string, default: "░"
    flag :filled_color, :string, default: "success"
    flag :empty_color, :string, default: "background"
    flag :show_percent, :boolean, default: true

    run fn opts ->
      Alaja.Components.Bar.render(opts.value,
        max: opts.max,
        label: opts.label,
        width: opts.width,
        filled_char: opts.filled_char,
        empty_char: opts.empty_char,
        filled_color: opts.filled_color,
        empty_color: opts.empty_color,
        show_percent: opts.show_percent
      )

      :ok
    end
  end
end
