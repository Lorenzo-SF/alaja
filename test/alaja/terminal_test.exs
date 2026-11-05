defmodule Alaja.TerminalTest do
  use ExUnit.Case

  alias Alaja.Terminal

  describe "size/0" do
    test "returns a tuple of two positive integers" do
      {cols, rows} = Terminal.size()
      assert is_integer(cols) and cols > 0
      assert is_integer(rows) and rows > 0
    end
  end

  describe "width/0" do
    test "returns a positive integer" do
      assert is_integer(Terminal.width()) and Terminal.width() > 0
    end
  end

  describe "height/0" do
    test "returns a positive integer" do
      assert is_integer(Terminal.height()) and Terminal.height() > 0
    end
  end

  describe "tty?/0" do
    test "returns a boolean" do
      assert is_boolean(Terminal.tty?())
    end

    test "is stable across calls (the value is cached)" do
      assert Terminal.tty?() == Terminal.tty?()
    end

    test "reconoce un dispositivo de caracteres real" do
      # Este es el test que faltaba. El anterior era
      #
      #     assert tty?() == match?(File.stat("/dev/fd/1").type == :device)
      #
      # que no afirmaba que la sonda fuese *correcta*, sino que
      # coincidía con su propia implementación. Eso sólo detecta un
      # resultado constante equivocado; si la sonda devuelve algo que no
      # es `:device` **porque el sistema no se parece a Linux**, ambos
      # lados valen `false` y el test pasa alegre con el bug presente.
      # Justo lo que pasa en macOS, donde `/dev/fd` es fdescfs y no
      # `/proc/self/fd`.
      #
      # `/dev/tty` es un `S_IFCHR` exista o no terminal de control, en
      # ambos sistemas. Si la sonda no lo reconoce, la sonda está rota.
      case :os.type() do
        {:unix, _} ->
          assert Terminal.device?("/dev/tty"),
                 "la sonda no reconoce un dispositivo de caracteres inequívoco"

        _ ->
          # Windows no tiene /dev; ahí `device?/0` siempre es false.
          refute Terminal.device?("/dev/tty")
      end
    end

    test "no confunde una tubería con un terminal" do
      # Bajo ExUnit, fd 1 es una tubería de captura. Esto no es
      # tautológico: dice algo sobre el disco, no sobre la función.
      refute Terminal.device?("/dev/fd/1")
    end

    test "un path inexistente no revienta" do
      refute Terminal.device?("/dev/definitely-not-a-real-device")
    end

    test "es false con la stdout capturada" do
      # ExUnit captura stdout, que es justo lo que este módulo existe
      # para evitar: un CLI que escupe ANSI a una tubería.
      refute Terminal.tty?()
    end
  end
end
