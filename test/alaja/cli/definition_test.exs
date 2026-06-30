defmodule Alaja.CLI.DefinitionTest do
  @moduledoc """
  Verifies the cast_flag_value/3 behaviour by exercising the public
  exec/1 entry point on a test-only CLI fixture
  (Alaja.CLITestFixture). The fixture captures its received opts in a
  NamedTuple on the calling process via capture/1, and tests assert on
  that.
  """

  use ExUnit.Case

  defp run_cli(args) do
    # exec/1 runs in a fresh task; the fixture's run callback reads
    # :alaja_test_pid from its own process dictionary to know where to
    # send the captured opts.
    test_pid = self()

    Task.async(fn ->
      Process.put(:alaja_test_pid, test_pid)
      Alaja.CLITestFixture.exec(["echo" | args])
    end)
    |> Task.await(2_000)

    receive do
      {:alaja_cli_capture, opts} -> opts
    after
      500 -> flunk("no capture received within 500ms for args: #{inspect(args)}")
    end
  end

  describe "cast_flag_value :integer" do
    test "parses valid integers" do
      opts = run_cli(["--n", "42"])
      assert opts.n == 42
    end

    test "returns the default on garbage input (no crash)" do
      opts = run_cli(["--n", "not-a-number"])
      assert opts.n == 0
    end
  end

  describe "cast_flag_value :float" do
    test "parses valid floats" do
      opts = run_cli(["--f", "3.14"])
      assert opts.f == 3.14
    end

    test "returns the default on garbage input (no crash)" do
      opts = run_cli(["--f", "garbage"])
      assert opts.f == 0.0
    end
  end

  describe "cast_flag_value :path" do
    test "expands ~ to the home directory" do
      opts = run_cli(["--p", "~/alaja.txt"])
      refute String.starts_with?(opts.p, "~")
      assert String.ends_with?(opts.p, "/alaja.txt")
    end
  end

  describe "cast_flag_value :url" do
    test "accepts https URLs" do
      opts = run_cli(["--u", "https://example.com/foo"])
      assert opts.u == "https://example.com/foo"
    end

    test "rejects non-http schemes" do
      opts = run_cli(["--u", "mailto:foo@bar.com"])
      assert opts.u == ""
    end
  end

  describe "cast_flag_value :color_list" do
    test "parses ; separated colors into RGB tuples" do
      opts = run_cli(["--colors", "red;blue;#FF6B6B"])
      assert {255, 0, 0} in opts.colors
      assert {0, 0, 255} in opts.colors
      assert {255, 107, 107} in opts.colors
    end

    test "returns the default on garbage input" do
      opts = run_cli(["--colors", "not-a-color;red"])
      assert opts.colors == []
    end
  end
end