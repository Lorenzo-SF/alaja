defmodule Alaja.CLI.Commands.Show.Ask do
  @moduledoc """
  `alaja ask` — Ask an interactive question.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "ask", "Ask an interactive text question" do
    argument :question, :string, required: false
    flag :color, :string, default: nil
    flag :align, :string, default: "left"

    run fn opts ->
      Alaja.Components.Ask.render(opts)
    end
  end
end
