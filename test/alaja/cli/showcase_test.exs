defmodule Alaja.CLI.ShowcaseTest do
  @moduledoc """
  Tests for the startup showcase: guard conditions and the multiline
  pulsar content. The interactive yes/no prompt itself is not exercised
  (needs a TTY); `enabled?/0` being false in tests guarantees the
  showcase never runs under `mix test`.
  """

  use ExUnit.Case, async: true

  alias Alaja.CLI.Showcase

  test "enabled?/0 is false when the showcase is disabled via env var" do
    System.put_env("ALAJ: NO_SHOWCASE", "1")

    try do
      refute Showcase.enabled?()
    after
      System.delete_env("ALAJ: NO_SHOWCASE")
    end
  end

  test "pulsar_text/0 builds the multiline message with the active theme" do
    text = Showcase.pulsar_text()

    assert [first, second, third] = String.split(text, "\n")
    assert first =~ "alaja"
    assert second == "Terminal UI & Process Orchestration Framework"
    assert third =~ "tema activo:"
  end
end
