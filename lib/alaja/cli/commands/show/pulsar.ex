defmodule Alaja.CLI.Commands.Show.Pulsar do
  @moduledoc """
  `alaja pulsar` — Display pulsar/radar animation with gradient wave effect.

  This CLI uses the `Alaja.CLI.Definition` DSL (iter-046) and is a
  thin wrapper: all parsing helpers and animation logic live in
  `Alaja.Components.Pulsar`.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "pulsar", "Pulsar/radar animation with gradient wave effect" do
    argument :text, :string, required: false
    flag :width, :integer, default: 40
    flag :height, :integer, default: 7
    flag :colors, :string, default: nil
    flag :color, :string, default: nil
    flag :speed, :integer, default: 100
    flag :align, :string, default: "center"
    flag :chars, :string, default: nil
    flag :direction, :string, default: "out"
    flag :"content-position-x", :integer, default: nil
    flag :"content-position-y", :integer, default: nil
    flag :content_type, :string, default: "text"
    flag :image_path, :string, default: nil
    flag :duration, :integer, default: nil

    run fn opts ->
      Alaja.CLI.Commands.Show.Pulsar.Handler.run(opts)
    end
  end
end
