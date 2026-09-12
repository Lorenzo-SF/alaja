defmodule Alaja.CLI.Commands.Show.Image do
  @moduledoc """
  `alaja image` — Display images in terminal.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.
  All rendering logic lives in `Alaja.ImageRenderer`.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "image", "Display images in the terminal" do
    argument :path, :string, required: false
    flag :width, :integer, default: 40
    flag :height, :integer, default: nil
    flag :protocol, :string, default: "auto"
    flag :to_ascii_art, :boolean, default: false
    flag :ascii_chars, :string, default: nil
    flag :ascii_color, :boolean, default: false
    flag :ascii_saturation, :float, default: nil
    flag :ascii_style, :string, default: "blocks"

    run fn opts ->
      Alaja.ImageRenderer.render(opts)
    end
  end
end
