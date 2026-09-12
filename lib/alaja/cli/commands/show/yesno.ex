defmodule Alaja.CLI.Commands.Show.YesNo do
  @moduledoc """
  `alaja yesno` — Ask a Yes/No question.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "yesno", "Ask an interactive Yes/No question" do
    argument :question, :string, required: false
    flag :default, :string, default: "no"
    flag :color, :string, default: nil
    flag :align, :string, default: "left"

    run fn opts ->
      Alaja.Components.YesNo.render(opts)
    end
  end
end
