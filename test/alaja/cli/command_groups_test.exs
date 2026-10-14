defmodule Alaja.CLI.CommandGroupsTest do
  @moduledoc """
  `use Alaja.CLI.Definition, groups: …` — agrupa el help global de un host.

  Una tabla plana de 37 comandos es una lista, no una referencia: obliga a
  recorrerla entera para encontrar el comando de la entidad que buscas. Los
  grupos la convierten en algo navegable, y son opt-in a propósito: un host
  que no declara `groups:` sigue viendo exactamente la tabla de siempre.

  Lo que se fija aquí:

    * `__command_groups__/0` devuelve lo declarado, y `[]` por defecto;
    * un host con grupos los ve en el help, cada uno con su título;
    * un comando que nadie agrupó aparece igualmente, bajo "Otros";
    * un host sin grupos no ve ningún título: la tabla no cambia.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  defmodule GroupedHost do
    @moduledoc "Host sintético que agrupa sus comandos."
    use Alaja.CLI.Definition,
      otp_app: :grouped_host,
      groups: [{"Lectura", ["read-one", "read-all"]}, {"Escritura", ["write-one"]}]

    command("read-one", "Lee uno", run: {__MODULE__, :noop})
    command("read-all", "Lee todos", run: {__MODULE__, :noop})
    command("write-one", "Escribe uno", run: {__MODULE__, :noop})
    command("orphan", "No está en ningún grupo", run: {__MODULE__, :noop})

    @doc false
    def noop(_opts), do: :ok
  end

  defmodule PlainHost do
    @moduledoc "Host sintético sin grupos: el caso por defecto."
    use Alaja.CLI.Definition, otp_app: :plain_host

    command("alpha", "Primero", run: {__MODULE__, :noop})
    command("beta", "Segundo", run: {__MODULE__, :noop})

    @doc false
    def noop(_opts), do: :ok
  end

  describe "__command_groups__/0" do
    test "devuelve los grupos declarados" do
      assert GroupedHost.__command_groups__() == [
               {"Lectura", ["read-one", "read-all"]},
               {"Escritura", ["write-one"]}
             ]
    end

    test "sin `groups:` es una lista vacía" do
      assert PlainHost.__command_groups__() == []
    end
  end

  describe "el help global de un host con grupos" do
    test "sale un título por grupo" do
      output = capture_io(fn -> GroupedHost.main(["--help"]) end)

      assert output =~ "Lectura"
      assert output =~ "Escritura"
    end

    test "los comandos caen en su grupo, no en el primero" do
      output = capture_io(fn -> GroupedHost.main(["--help"]) end)

      lectura = section(output, "Lectura", "Escritura")
      escritura = section(output, "Escritura", nil)

      assert lectura =~ "read-one"
      assert lectura =~ "read-all"
      refute lectura =~ "write-one"

      assert escritura =~ "write-one"
      refute escritura =~ "read-all"
    end

    test "un comando sin agrupar aparece igualmente, bajo 'Otros'" do
      output = capture_io(fn -> GroupedHost.main(["--help"]) end)

      otros = section(output, "Otros", nil)

      assert otros =~ "orphan"
    end

    test "ningún comando se pierde: la referencia los menciona todos" do
      output = capture_io(fn -> GroupedHost.main(["--help"]) end)

      for name <- ~w(read-one read-all write-one orphan) do
        assert output =~ name, "el help no menciona '#{name}'"
      end
    end

    test "sigue siendo el help del host, no el de alaja" do
      output = capture_io(fn -> GroupedHost.main(["--help"]) end)

      assert output =~ "Grouped_host" or output =~ "grouped_host"
      refute output =~ "Suggested Palette"
    end
  end

  describe "el help global de un host sin grupos no cambia" do
    test "no aparece ningún título de grupo" do
      output = capture_io(fn -> PlainHost.main(["--help"]) end)

      assert output =~ "alpha"
      assert output =~ "beta"
      refute output =~ "Otros"
    end

    test "el contrato antiguo —una sola tabla— sigue valiendo" do
      output = capture_io(fn -> PlainHost.main(["--help"]) end)

      assert output =~ "Command"
      assert output =~ "Description"
    end
  end

  describe "el camino del help" do
    test "los cuatro spellings dan el mismo help agrupado" do
      long = capture_io(fn -> GroupedHost.main(["--help"]) end)
      short = capture_io(fn -> GroupedHost.main(["-h"]) end)
      word = capture_io(fn -> GroupedHost.main(["help"]) end)
      empty = capture_io(fn -> GroupedHost.main([]) end)

      for output <- [short, word, empty] do
        assert output =~ "Lectura"
        assert output =~ "Escritura"
        assert output =~ "Otros"
      end

      assert long =~ "Lectura"
    end
  end

  # El texto que sale desde un título hasta el siguiente, para poder
  # afirmar "este comando está en ESTE grupo" sin depender del ancho de
  # la tabla ni del orden de las columnas.
  defp section(output, title, next_title) do
    [_before, rest] = String.split(output, title, parts: 2)

    case next_title && String.split(rest, next_title, parts: 2) do
      [chunk, _rest] -> chunk
      _ -> rest
    end
  end
end
