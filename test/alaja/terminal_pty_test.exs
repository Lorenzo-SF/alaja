defmodule Alaja.TerminalPtyTest do
  @moduledoc """
  La sonda de TTY, contra una terminal de verdad.

  `Alaja.TerminalTest` comprueba que `device?/1` reconoce un dispositivo
  de caracteres inequívoco. Eso no basta: lo que hay que verificar es que
  `/dev/fd/1` **signifique lo mismo en todas partes**.

  En Linux `/dev/fd` es un symlink a `/proc/self/fd`, así que `stat` sigue
  el enlace hasta el objeto real: un terminal da `:device` y una tubería
  `:other`. En macOS `/dev/fd` es fdescfs, con otra semántica. Si ahí no
  devuelve `:device`, `tty?/0` devuelve `false` siempre y todo Alaja se
  queda sin color en el Mac de quien lo usa.

  El test que cubría esto antes —

      assert tty?() == match?(File.stat("/dev/fd/1").type == :device)

  — no lo detectaba: afirmaba que la función coincidía con su propia
  implementación, así que en macOS daba `false == false` y pasaba con el
  bug presente.

  Aquí se monta una pty de verdad y se arranca un BEAM nuevo dentro. El
  resultado depende del sistema donde corra, que es lo que hay que
  comprobar: **este test pasa en Linux, y en macOS sólo pasa si la sonda
  funciona allí.** Si algún día deja de funcionar en macOS, lo dice la
  suite en lugar de quejarse un usuario.

  Se salta donde no hay pty (`script` ausente) o no es Unix.
  """

  use ExUnit.Case

  @moduletag timeout: 120_000

  setup_all do
    {supported, probe} = build_probe()

    # La limpieza va aquí y no en `on_exit` de cada test: los dos tests
    # comparten el mismo fichero, y el primero que acabara borrando su
    # directorio dejaría al segundo sin probe.
    if supported do
      {_script, _paths, dir} = probe
      on_exit(fn -> File.rm_rf(dir) end)
    end

    {:ok, supported: supported, probe: probe}
  end

  describe "tty?/0 con una terminal real delante" do
    test "devuelve true cuando fd 1 es una pty", %{supported: supported, probe: probe} do
      if supported do
        {script, paths, _dir} = probe

        output = under_pty(script, paths)

        assert output =~ "TTY=true",
               """
               bajo una pty real, tty?/0 dio:

                 #{inspect(output)}

               En macOS eso significa que File.stat("/dev/fd/1") no devuelve
               :device. La suposición de que /dev/fd se comporta como
               /proc/self/fd no se cumple y hay que cambiar de primitiva.
               """
      else
        # Sin `script` no hay pty que montar. No hay nada que afirmar, y
        # fingir que sí lo haría es lo que trajo este bug dos años abajo.
        :ok
      end
    end

    test "devuelve false cuando fd 1 es una tubería", %{supported: supported, probe: probe} do
      if supported do
        {script, paths, _dir} = probe

        # Sin `script`: la salida va a una tubería, como cuando alguien
        # hace `acho --help | less`.
        {out, _status} =
          System.cmd("elixir", ["-pa", paths, script], stderr_to_stdout: true)

        assert out =~ "TTY=false"
      else
        :ok
      end
    end
  end

  # ── andamiaje ──────────────────────────────────────────────────────

  defp build_probe do
    supported? =
      match?({:unix, _}, :os.type()) and
        System.find_executable("script") != nil

    if supported?, do: {true, write_probe()}, else: {false, nil}
  end

  # Un BEAM limpio que sólo carga los .beam de Alaja. Nada de `mix run`:
  # mix fija `:elixir, :ansi_enabled` a false en cuanto detecta que stdout
  # no es terminal, y ese es exactamente el camino que enmascara el fallo.
  # Aquí nadie ha decidido nada y la sonda tiene que responder sola.
  defp write_probe do
    dir =
      Path.join(System.tmp_dir!(), "alaja_tty_probe_#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    script = Path.join(dir, "probe.exs")
    File.write!(script, ~s|IO.puts("TTY=" <> inspect(Alaja.Terminal.tty?()))\n|)

    {script, alaja_ebin(), dir}
  end

  defp alaja_ebin do
    candidates = [
      Path.join(Mix.Project.build_path(), "lib/alaja/ebin"),
      Path.expand("../../_build/test/lib/alaja/ebin", __DIR__)
    ]

    Enum.find(candidates, &File.dir?/1) || List.first(candidates)
  end

  # `script` no tiene la misma sintaxis en Linux (util-linux) y en macOS
  # (BSD). Se invoca justo la forma que cada sistema espera.
  defp under_pty(script, paths) do
    case :os.type() do
      {:unix, :darwin} ->
        {out, _status} =
          System.cmd("script", ["-q", "/dev/null", "elixir", "-pa", paths, script],
            stderr_to_stdout: true
          )

        out

      {:unix, _} ->
        {out, _status} =
          System.cmd("script", ["-qec", "elixir -pa #{paths} #{script}", "/dev/null"],
            stderr_to_stdout: true
          )

        out
    end
  end
end
