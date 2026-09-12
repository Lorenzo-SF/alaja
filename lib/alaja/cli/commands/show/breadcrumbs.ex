defmodule Alaja.CLI.Commands.Show.Breadcrumbs do
  @moduledoc """
  `alaja breadcrumbs` — Display navigation breadcrumbs.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "breadcrumbs", "Display navigation breadcrumbs" do
    argument :items, :string, required: false
    flag :separator, :string, default: "›"
    flag :color, :string, default: nil
    flag :separator_color, :string, default: nil
    flag :current_color, :string, default: nil

    run fn opts ->
      Alaja.Components.Breadcrumbs.render(opts)
    end
  end
end
