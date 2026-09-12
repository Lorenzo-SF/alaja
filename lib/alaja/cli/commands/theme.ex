defmodule Alaja.CLI.Commands.Theme do
  @moduledoc """
  `alaja theme` — Manage themes (init, set, list, show).

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "theme", "Manage themes" do
    argument :action, :string, required: true
    argument :name, :string, required: false

    run fn opts ->
      Alaja.CLI.Theme.handle(opts)
    end
  end
end
