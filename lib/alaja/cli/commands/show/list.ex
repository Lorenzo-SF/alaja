defmodule Alaja.CLI.Commands.Show.List do
  @moduledoc """
  `alaja list` — Display a styled bullet list.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "list", "Display a styled bullet list" do
    argument :items, :string, required: false
    flag :header, :string, default: nil
    flag :color, :string, default: nil
    flag :align, :string, default: "left"

    run fn opts ->
      Alaja.Components.List.render(opts)
    end
  end
end
