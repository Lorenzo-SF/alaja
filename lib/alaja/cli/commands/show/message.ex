defmodule Alaja.CLI.Commands.Show.Message do
  @moduledoc """
  `alaja message|success|error|warning|info|...` — Display formatted messages.

  iter-046: rewritten with `Alaja.CLI.Definition` DSL.

  Multiple typed commands (success, error, warning, info, debug, notice,
  critical, alert, emergency, happy, sad) all delegate to the
  generic `message` command with a `:type` flag.
  """

  use Alaja.CLI.Definition, otp_app: :alaja

  command "message", "Display a custom formatted message with full styling" do
    argument :text, :string, required: false
    flag :text2, :string, default: nil
    flag :text3, :string, default: nil
    flag :color, :string, default: nil
    flag :bg_color, :string, default: nil
    flag :bold, :boolean, default: false
    flag :italic, :boolean, default: false
    flag :underline, :boolean, default: false
    flag :dim, :boolean, default: false
    flag :blink, :boolean, default: false
    flag :reverse, :boolean, default: false
    flag :hidden, :boolean, default: false
    flag :strikethrough, :boolean, default: false
    flag :padding, :integer, default: 0
    flag :addline, :string, default: nil
    flag :type, :string, default: nil

    run fn opts ->
      Alaja.CLI.Commands.Show.Message.Handler.run(opts)
    end
  end
end
