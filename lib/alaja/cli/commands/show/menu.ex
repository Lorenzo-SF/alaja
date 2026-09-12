defmodule Alaja.CLI.Commands.Show.Menu do
  @moduledoc """
  `alaja menu` — Display an interactive selection menu.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "menu", "Display an interactive selection menu" do
    argument :items, :string, required: false
    flag :header, :string, default: nil
    flag :color, :string, default: nil
    flag :align, :string, default: "left"

    run fn opts ->
      Alaja.Components.Menu.render(opts)
    end
  end
end
