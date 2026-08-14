defmodule Alaja.CLI.ColorTest do
  use ExUnit.Case

  alias Alaja.CLI.Color

  describe "parse/1 — formato estricto <formato>:<codigo>" do
    test "rgb con separador ;" do
      assert {:ok, {255, 0, 0}} = Color.parse("rgb:255;0;0")
    end

    test "rgb con separador ," do
      assert {:ok, {255, 0, 0}} = Color.parse("rgb:255,0,0")
    end

    test "hex con #" do
      assert {:ok, {255, 0, 0}} = Color.parse("hex:#ff0000")
    end

    test "hex sin #" do
      assert {:ok, {0, 128, 255}} = Color.parse("hex:0080ff")
    end

    test "cmyk con ;" do
      assert {:ok, {255, 0, 0}} = Color.parse("cmyk:0;100;100;0")
    end

    test "argb" do
      assert {:ok, {0, 255, 0}} = Color.parse("argb:255;0;255;0")
    end

    test "hsl" do
      assert {:ok, {255, 0, 0}} = Color.parse("hsl:0;100;50")
    end

    test "hsv" do
      assert {:ok, {255, 0, 0}} = Color.parse("hsv:0;100;100")
    end

    test "xterm" do
      assert {:ok, {0, 0, 0}} = Color.parse("xterm:0")
    end

    test "theme con key existente resuelve al tema activo" do
      assert {:ok, {_, _, _}} = Color.parse("theme:primary")
    end

    test "theme con key inexistente → blanco por defecto" do
      assert {:ok, {255, 255, 255}} = Color.parse("theme:no_existe_esta_key")
    end

    test "color suelto sin formato → error claro" do
      assert {:error, msg} = Color.parse("cyan")
      assert msg =~ "cyan"
      assert msg =~ "missing format"
    end

    test "basura → error" do
      assert {:error, msg} = Color.parse("basura")
      assert msg =~ "basura"
    end

    test "formato desconocido → error" do
      assert {:error, msg} = Color.parse("foobar:1;2;3")
      assert msg =~ "foobar"
    end

    test "rgb fuera de rango → error" do
      assert {:error, msg} = Color.parse("rgb:999;0;0")
      assert msg =~ "rgb:999;0;0"
    end
  end

  describe "parse_list/1 — separador |" do
    test "lista de colores con formato" do
      assert {:ok, [{255, 0, 0}, {0, 255, 0}]} =
               Color.parse_list("rgb:255;0;0|rgb:0;255;0")
    end

    test "lista mixta con theme" do
      assert {:ok, [_, {255, 255, 255}]} =
               Color.parse_list("theme:primary|theme:key_inexistente")
    end

    test "error indica el color que falló" do
      assert {:error, msg} = Color.parse_list("rgb:255;0;0|cyan")
      assert msg =~ "cyan"
      assert msg =~ "invalid color"
    end

    test "nil pasa" do
      assert nil == Color.parse_list(nil)
      assert nil == Color.parse(nil)
    end
  end
end