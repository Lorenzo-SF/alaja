defmodule Alaja.CLI.UnknownFlagPositionalTest do
  @moduledoc """
  Un flag desconocido no puede comerse el argumento posicional.

  `allow_unknown_flags: true` es lo que permite una hot call con flags
  arbitrarios, pero el flag tragado ocupaba la primera ranura de los
  posicionales y `parse_arguments` se lo asignaba al primer `argument`
  declarado:

      $ acho show-call mi_call --typo=1
      Error: call '--typo=1' no encontrada

  El síntoma era "no existe lo que pediste" cuando el problema real era
  que no se entendió lo que se pidió.
  """

  use ExUnit.Case, async: true

  defmodule Probe do
    @moduledoc "CLI sintética que devuelve los opts que recibe."
    use Alaja.CLI.Definition,
      otp_app: :alaja,
      allow_unknown_flags: true,
      usage_exit_code: 2

    command "probe", "Vuelve sus opts" do
      argument(:name, :string, required: false)
      argument(:other, :string, required: false)
      flag(:collection, :string)
      run({__MODULE__, :handler})
    end

    @doc false
    def handler(opts) do
      # El handler corre en este mismo proceso —la captura no crea otro—
      # así que el pid de `setup` está en el diccionario, no en el
      # registro de nombres: `Process.get/1`, no `whereis/1`.
      send(Process.get(:test_pid), {:opts, opts})

      :ok
    end
  end

  setup do
    Process.put(:test_pid, self())
    :ok
  end

  defp run(args) do
    capture = ExUnit.CaptureIO.capture_io(:stdio, fn -> Probe.main(args) end)
    assert_receive {:opts, opts}, 2_000
    {opts, capture}
  end

  test "un flag desconocido no se cuela en el primer argumento" do
    {opts, _} = run(["probe", "mi_call", "--collection=api", "--typo=1"])

    assert opts.name == "mi_call",
           "el flag se comió el posicional: #{inspect(opts.name)}"

    assert opts.collection == "api"
  end

  test "el flag sigue disponible para el handler, detrás de los posicionales" do
    {opts, _} = run(["probe", "uno", "dos", "--typo=1"])

    assert opts.name == "uno"
    assert opts.other == "dos"
    assert "--typo=1" in opts._args
  end

  test "el orden de los tokens no cambia el resultado" do
    {antes, _} = run(["probe", "mi_call", "--typo=1"])
    {despues, _} = run(["probe", "--typo=1", "mi_call"])

    assert antes.name == "mi_call"
    assert despues.name == "mi_call"
  end

  test "sin flags raros el posicional sigue donde estaba" do
    {opts, _} = run(["probe", "mi_call", "--collection=api"])

    assert opts.name == "mi_call"
    assert opts.collection == "api"
  end
end
