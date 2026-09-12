defmodule Alaja.CLI.Commands.Show.Json do
  @moduledoc """
  `alaja json` — Pretty-print JSON with syntax highlighting.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "json", "Pretty-print JSON with syntax highlighting" do
    argument :json_string, :string, required: false
    flag :indent, :integer, default: 2
    flag :key_color, :string, default: nil
    flag :string_color, :string, default: nil
    flag :number_color, :string, default: nil
    flag :boolean_color, :string, default: nil
    flag :null_color, :string, default: nil
    flag :punctuation_color, :string, default: nil

    run fn opts ->
      Alaja.Components.Json.render(opts)
    end
  end
end
