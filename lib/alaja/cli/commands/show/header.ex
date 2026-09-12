defmodule Alaja.CLI.Commands.Show.Header do
  @moduledoc """
  `alaja header` — Display styled headers.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  All parsing logic lives in `Alaja.Components.Header`.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "header", "Display styled headers with optional subtitle" do
    argument :title, :string, required: false
    flag :subtitle, :string, default: nil
    flag :size, :string, default: "medium"
    flag :color, :string, default: nil
    flag :subtitle_color, :string, default: nil
    flag :separator_char, :string, default: nil
    flag :separator_color, :string, default: nil
    flag :separator_length, :integer, default: nil

    run fn opts ->
      Alaja.Components.Header.render(opts)
    end
  end
end
