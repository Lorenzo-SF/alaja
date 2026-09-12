defmodule Alaja.CLI.Commands.Action do
  @moduledoc """
  `alaja action` — Execute Alaja commands from JSON input.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "action", "Execute Alaja commands from JSON input" do
    flag :file, :string, default: nil
    flag :data, :string, default: nil
    flag :batch, :boolean, default: false

    run fn opts ->
      Alaja.CLI.Actions.execute(opts)
    end
  end
end
