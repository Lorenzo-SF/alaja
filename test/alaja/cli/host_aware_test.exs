defmodule Alaja.CLI.HostAwareTest do
  @moduledoc """
  Behavioural tests confirming that `Alaja.CLI.Definition`, when used
  as a library by a host application, never leaks Alaja's own command
  catalogue into the host's CLI surface.

  Each host module gets its own `@commands` accumulator (set up by the
  `__using__` macro). The dispatcher branches on
  `__otp_app__/0` so that:

    * When the host's otp_app is `:alaja` (i.e. the `alaja` binary
      itself), the full Alaja reference is rendered.
    * When the host's otp_app is anything else (arrea, delfos, acho,
      zaguan, ...), only the host's commands are rendered and
      branded with the host's name.

  These tests run a synthetic host module through the DSL and verify
  the static contract (otp_app + commands list) at compile time.
  Runtime behaviour (`main/1`) is exercised by integration tests
  in each consuming project (arrea, delfos, ...).
  """

  use ExUnit.Case, async: true

  defmodule FakeHost do
    @moduledoc "Synthetic host module used by the test only."
    use Alaja.CLI.Definition, otp_app: :fake_host

    command("greet", "Say hi to someone", run: {__MODULE__, :greet_handler})

    command("farewell", "Say goodbye", run: {__MODULE__, :farewell_handler})

    @doc false
    def greet_handler(_opts), do: :ok

    @doc false
    def farewell_handler(_opts), do: :ok
  end

  describe "FakeHost.__otp_app__/0" do
    test "returns the otp_app declared in use Alaja.CLI.Definition" do
      assert FakeHost.__otp_app__() == :fake_host
    end
  end

  describe "FakeHost.__commands__/0" do
    test "only contains commands declared in this module" do
      names = FakeHost.__commands__() |> Enum.map(& &1.name)

      assert "greet" in names
      assert "farewell" in names
    end

    test "does NOT contain commands from Alaja.CLI" do
      names = FakeHost.__commands__() |> Enum.map(& &1.name)

      refute "success" in names
      refute "error" in names
      refute "warning" in names
      refute "info" in names
      refute "message" in names
      refute "header" in names
      refute "gradient" in names
      refute "table" in names
      refute "pulsar" in names
      refute "showcase" in names
    end
  end

  describe "FakeHost command structure" do
    test "greet command has the expected shape" do
      [greet | _] = FakeHost.__commands__() |> Enum.filter(&(&1.name == "greet"))

      assert greet.description == "Say hi to someone"
      assert is_list(greet.flags)
      assert is_list(greet.arguments)
      assert is_map(greet.subcommands)
      assert greet.run == {FakeHost, :greet_handler}
    end

    test "farewell command has the expected shape" do
      [farewell | _] = FakeHost.__commands__() |> Enum.filter(&(&1.name == "farewell"))

      assert farewell.description == "Say goodbye"
      assert farewell.run == {FakeHost, :farewell_handler}
    end
  end

  describe "Alaja.CLI.__commands__/0" do
    test "still contains the canonical alaja commands" do
      names = Alaja.CLI.__commands__() |> Enum.map(& &1.name)

      assert "success" in names
      assert "error" in names
      assert "warning" in names
      assert "info" in names
      assert "message" in names
      assert "header" in names
      assert "gradient" in names
      assert "table" in names
    end

    test "Alaja.CLI.__otp_app__/0 returns :alaja" do
      assert Alaja.CLI.__otp_app__() == :alaja
    end
  end

  describe "module isolation" do
    test "FakeHost's commands do not leak into Alaja.CLI" do
      alaja_names = Alaja.CLI.__commands__() |> Enum.map(& &1.name)
      refute "greet" in alaja_names
      refute "farewell" in alaja_names
    end

    test "Alaja.CLI's commands do not leak into FakeHost" do
      host_names = FakeHost.__commands__() |> Enum.map(& &1.name)
      refute "pulsar" in host_names
      refute "showcase" in host_names
    end
  end
end
