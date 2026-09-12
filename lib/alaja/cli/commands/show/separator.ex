defmodule Alaja.CLI.Commands.Show.Separator do
  @moduledoc """
  `alaja separator` — Display horizontal separator lines.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "separator", "Display horizontal separator lines" do
    flag :char, :string, default: "─"
    flag :text, :string, default: nil
    flag :separator_color, :string, default: nil
    flag :text_color, :string, default: nil
    flag :width, :integer, default: nil

    run fn opts ->
      Alaja.Components.Separator.render(opts)
    end
  end
end
