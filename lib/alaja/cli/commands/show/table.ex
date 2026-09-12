defmodule Alaja.CLI.Commands.Show.Table do
  @moduledoc """
  `alaja table` — Display formatted tables.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  All parsing logic lives in `Alaja.Components.Table` and `Base`.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "table", "Display formatted tables with borders and styling" do
    flag :headers, :string, default: nil
    flag :rows, :string, default: nil
    flag :border, :string, default: "single"
    flag :padding, :integer, default: 1
    flag :border_color, :string, default: nil
    flag :border_effects, :string, default: nil
    flag :headers_color, :string, default: nil
    flag :headers_align, :string, default: "center"
    flag :headers_effects, :string, default: nil
    flag :rows_color, :string, default: nil
    flag :rows_align, :string, default: "left"
    flag :rows_effects, :string, default: nil
    flag :table_align, :string, default: "left"
    flag :separator, :string, default: ";"
    flag :verbose, :boolean, default: false

    run fn opts ->
      Alaja.Components.Table.render(opts)
    end
  end
end
