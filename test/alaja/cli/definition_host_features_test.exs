defmodule Alaja.CLI.DefinitionHostFeaturesTest do
  @moduledoc """
  Extensiones del DSL que un host necesita y Alaja no traía:

    * `catch_all` — un primer token que no es comando sigue siendo válido
    * `command_help` — `alaja <cmd> --help` renderiza ese comando
    * `Alaja.CLI.Exit` — código de salida propio del host
    * matching exacto de flags, con variante dashed
  """

  use ExUnit.Case, async: true

  defmodule Handler do
    @moduledoc false
    def run(opts), do: {:ran, opts}
    def unknown(_opts), do: :catch_all_took
  end

  defmodule StrictCLI do
    @moduledoc false
    use Alaja.CLI.Definition, otp_app: :alaja

    command "plain", "No flags at all" do
      flag(:auth_type, :string)
      run({Handler, :run})
    end
  end

  defmodule PositionalCLI do
    @moduledoc false
    use Alaja.CLI.Definition, otp_app: :alaja

    command "alpha", "Dos positionals" do
      argument(:hash, :string, required: true)
      argument(:name, :string, required: false)
      run({Handler, :run})
    end
  end

  defmodule HostCLI do
    @moduledoc false
    use Alaja.CLI.Definition,
      otp_app: :alaja,
      allow_unknown_flags: true,
      catch_all: {Handler, :unknown}

    command "greet", "Say hello" do
      flag(:name, :string, required: true, short: :n)
      flag(:auth_type, :string)
      run({Handler, :run})
    end

    command "plain", "No flags at all" do
      run({Handler, :run})
    end
  end

  describe "catch_all/1" do
    test "an unknown first token is handed to the catch-all handler" do
      assert HostCLI.exec(["stored_call", "--payload=x"]) == :catch_all_took
    end

    test "an invocation that starts with a flag is handed to the catch-all" do
      assert HostCLI.exec(["--url=https://x", "--method=GET"]) == :catch_all_took
    end

    test "a known command still dispatches normally" do
      assert {:ran, %{name: "ana"}} = HostCLI.exec(["greet", "--name=ana"])
    end

    test "__catch_all__/0 exposes the handler" do
      assert HostCLI.__catch_all__() == {Handler, :unknown}
    end
  end

  describe "flag matching" do
    test "the exact name matches" do
      assert {:ran, %{name: "ana"}} = HostCLI.exec(["greet", "--name", "ana"])
    end

    test "the value after = is not part of the name" do
      assert {:ran, %{auth_type: "api-key"}} =
               HostCLI.exec(["greet", "--name=ana", "--auth-type=api-key"])
    end

    test "a flag declared underscored also answers to its dashed spelling" do
      assert {:ran, %{auth_type: "bearer"}} =
               HostCLI.exec(["greet", "--name=ana", "--auth_type=bearer"])

      assert {:ran, %{auth_type: "bearer"}} =
               HostCLI.exec(["greet", "--name=ana", "--auth-type=bearer"])
    end

    test "a prefix does not satisfy a declared flag" do
      # `--auth_typ` is a typo, not `:auth_type`. With
      # `allow_unknown_flags` it falls through untouched instead of
      # silently filling the field.
      assert {:ran, opts} = HostCLI.exec(["greet", "--name=ana", "--auth_typ=bearer"])
      assert opts.auth_type == nil
      assert opts._args == ["--auth_typ=bearer"]
    end

    test "a typo is rejected when unknown flags are refused" do
      import ExUnit.CaptureIO

      stderr =
        capture_io(:stderr, fn -> catch_exit(StrictCLI.exec(["plain", "--auth-typ=x"])) end)

      assert stderr =~ "unknown flag"
      assert stderr =~ "--auth-typ"
    end

    test "a typo suggests the flag the user meant" do
      import ExUnit.CaptureIO

      stderr =
        capture_io(:stderr, fn -> catch_exit(StrictCLI.exec(["plain", "--auth-typ=x"])) end)

      assert stderr =~ "Did you mean?"
      assert stderr =~ "--auth_type"
    end

    test "a short flag matches" do
      assert {:ran, %{name: "ana"}} = HostCLI.exec(["greet", "-n", "ana"])
    end
  end

  describe "accepted_long_names/1" do
    test "lists both spellings with the -- prefix" do
      assert "--auth_type" in Alaja.CLI.Definition.accepted_long_names(%{
               name: :auth_type,
               dashed: true
             })

      assert "--auth-type" in Alaja.CLI.Definition.accepted_long_names(%{
               name: :auth_type,
               dashed: true
             })
    end

    test "dashed: false removes the dashed spelling" do
      names = Alaja.CLI.Definition.accepted_long_names(%{name: :auth_type, dashed: false})

      assert "--auth_type" in names
      refute "--auth-type" in names
    end

    test "a name without underscores has one spelling" do
      assert ["--name"] = Alaja.CLI.Definition.accepted_long_names(%{name: :name, dashed: true})
    end
  end

  describe "command_help/1" do
    test "a leading flag is not a per-command help request" do
      assert Alaja.CLI.Definition.command_help(["--help"]) == :ok
      assert Alaja.CLI.Definition.command_help(["--url=x"]) == :ok
    end

    test "a named command with --help is a per-command request" do
      assert {:help, ["greet", "--help"]} = Alaja.CLI.Definition.command_help(["greet", "--help"])
      assert {:help, ["greet", "-h"]} = Alaja.CLI.Definition.command_help(["greet", "-h"])
    end

    test "a named command without help is not a request" do
      assert Alaja.CLI.Definition.command_help(["greet", "--name=ana"]) == :ok
    end
  end

  describe "render_command_help_for/3" do
    test "reports an unknown command so the host can fall through" do
      commands = HostCLI.__commands__()

      assert {:error, :unknown_command} =
               Alaja.CLI.Definition.render_command_help_for(commands, :alaja, ["nope", "--help"])
    end

    test "renders the command's flags when the command exists" do
      commands = HostCLI.__commands__()

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Alaja.CLI.Definition.render_command_help_for(commands, :alaja, ["greet", "--help"])
        end)

      assert output =~ "--name"
      assert output =~ "--auth-type"
    end
  end

  describe "strip_help_flag/1" do
    test "removes both spellings and leaves the rest" do
      assert ["greet", "--name=ana"] =
               Alaja.CLI.Definition.strip_help_flag(["greet", "--help", "--name=ana"])

      assert ["greet"] = Alaja.CLI.Definition.strip_help_flag(["greet", "-h"])
    end
  end

  describe "positionals do not stop flag parsing" do
    test "a flag after a positional is still parsed" do
      assert {:ran, %{name: "ana", _args: ["abc123"]}} =
               HostCLI.exec(["greet", "abc123", "--name=ana"])
    end

    test "positionals keep their order" do
      assert {:ran, %{_args: ["a", "b"]}} = HostCLI.exec(["plain", "a", "b"])
    end

    test "los posicionales llegan en el orden en que se escribieron" do
      assert {:ran, %{_args: ["primero", "segundo"], hash: "primero", name: "segundo"}} =
               PositionalCLI.exec(["alpha", "primero", "segundo"])
    end

    test "a flag before the positional is unaffected" do
      assert {:ran, %{name: "ana", _args: ["abc"]}} = HostCLI.exec(["greet", "--name=ana", "abc"])
    end

    test "an unknown flag still stops and is reported" do
      import ExUnit.CaptureIO

      stderr =
        capture_io(:stderr, fn -> catch_exit(StrictCLI.exec(["plain", "x", "--auth-typ=1"])) end)

      assert stderr =~ "unknown flag"
    end
  end

  describe "Alaja.CLI.Exit" do
    test "carries a message and an exit code" do
      error = Alaja.CLI.Exit.new("env 'prod' no encontrado", 11)

      assert Exception.message(error) == "env 'prod' no encontrado"
      assert error.exit_code == 11
    end

    test "can be raised and rescued as an exception" do
      assert_raise Alaja.CLI.Exit, "boom", fn ->
        raise Alaja.CLI.Exit, message: "boom", exit_code: 20
      end
    end
  end
end
