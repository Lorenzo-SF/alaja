defmodule Alaja.CLI.CommandExamplesTest do
  @moduledoc """
  `use Alaja.CLI.Definition, examples: …` — el recorrido, al final del help.

  Una referencia de comandos dice qué hay. No dice por dónde se empieza, y
  esa secuencia —crea el env, crea el autologin, crea la call, ejecútala—
  es justo lo que nadie recuerda de memoria y lo que más cuesta reconstruir.

  Lo que se fija aquí:

    * `__command_examples__/0` devuelve lo declarado, y `[]` por defecto;
    * con ejemplos, salen al final con su título y sus líneas;
    * sin ejemplos no se imprime nada: un host que no adopta la opción no
      cambia de output, ni un byte;
    * funcionan igual con `groups:` y sin él.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  defmodule ExampleHost do
    @moduledoc "Host sintético con ejemplos y sin grupos."
    use Alaja.CLI.Definition,
      otp_app: :example_host,
      examples: [
        {"Set up an environment", ["acho new-env --name=production"]},
        {"Run it by name", ["acho get_users", "acho get_users --env=staging"]}
      ]

    command("new-env", "Crea un env", run: {__MODULE__, :noop})
    command("get_users", "Ejecuta una call por su nombre", run: {__MODULE__, :noop})

    @doc false
    def noop(_opts), do: :ok
  end

  defmodule GroupedExamplesHost do
    @moduledoc "Host sintético con grupos y ejemplos a la vez."
    use Alaja.CLI.Definition,
      otp_app: :grouped_examples_host,
      groups: [{"Entornos", ["new-env"]}],
      examples: [{"Empieza por aquí", ["acho new-env --name=production"]}]

    command("new-env", "Crea un env", run: {__MODULE__, :noop})
    command("otro", "Otro comando", run: {__MODULE__, :noop})

    @doc false
    def noop(_opts), do: :ok
  end

  defmodule PlainHost do
    @moduledoc "Host sintético sin ejemplos: el caso por defecto."
    use Alaja.CLI.Definition, otp_app: :plain_host

    command("alpha", "Primero", run: {__MODULE__, :noop})

    @doc false
    def noop(_opts), do: :ok
  end

  describe "__command_examples__/0" do
    test "devuelve los ejemplos declarados" do
      assert ExampleHost.__command_examples__() == [
               {"Set up an environment", ["acho new-env --name=production"]},
               {"Run it by name", ["acho get_users", "acho get_users --env=staging"]}
             ]
    end

    test "sin `examples:` es una lista vacía" do
      assert PlainHost.__command_examples__() == []
    end
  end

  describe "el help global con ejemplos" do
    test "sale una sección EXAMPLES con cada título" do
      output = capture_io(fn -> ExampleHost.main(["--help"]) end)

      assert output =~ "EXAMPLES"
      assert output =~ "Set up an environment"
      assert output =~ "Run it by name"
    end

    test "las líneas salen indentadas y tal cual, para poder copiar" do
      output = capture_io(fn -> ExampleHost.main(["--help"]) end)

      assert output =~ "  acho new-env --name=production"
      assert output =~ "  acho get_users --env=staging"
    end

    test "los ejemplos van DESPUÉS de la tabla de comandos" do
      output = capture_io(fn -> ExampleHost.main(["--help"]) end)

      commands_at = :binary.match(output, "new-env") |> elem(0)
      examples_at = :binary.match(output, "EXAMPLES") |> elem(0)

      assert commands_at < examples_at,
             "los ejemplos se imprimieron antes de los comandos: no es una guía de arranque"
    end

    test "sigue siendo el help del host, con su tabla de comandos" do
      output = capture_io(fn -> ExampleHost.main(["--help"]) end)

      assert output =~ "new-env"
      assert output =~ "get_users"
      refute output =~ "Suggested Palette"
    end
  end

  describe "coexisten grupos y ejemplos" do
    test "salen los dos, cada uno en su sitio" do
      output = capture_io(fn -> GroupedExamplesHost.main(["--help"]) end)

      assert output =~ "Entornos"
      assert output =~ "EXAMPLES"
      assert output =~ "Empieza por aquí"
    end

    test "ningún comando se pierde por agrupar" do
      output = capture_io(fn -> GroupedExamplesHost.main(["--help"]) end)

      assert output =~ "new-env"
      assert output =~ "otro"
    end
  end

  describe "sin ejemplos no cambia nada" do
    test "no aparece la sección EXAMPLES" do
      output = capture_io(fn -> PlainHost.main(["--help"]) end)

      refute output =~ "EXAMPLES"
    end

    test "el help conserva su forma de siempre" do
      output = capture_io(fn -> PlainHost.main(["--help"]) end)

      assert output =~ "alpha"
      assert output =~ "Command"
      assert output =~ "Description"
    end
  end
end
