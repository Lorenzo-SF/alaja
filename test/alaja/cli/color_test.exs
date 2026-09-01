defmodule Alaja.CLI.ColorTest do
  use ExUnit.Case

  alias Alaja.CLI.Color

  describe "parse accepts uppercase formats" do
    test "CMYK:10;40;60;8" do
      assert {:ok, _} = Color.parse("CMYK:10;40;60;8")
    end

    test "HEX:ff3940" do
      assert {:ok, _} = Color.parse("HEX:ff3940")
    end

    test "Argb:44;141;255;10" do
      assert {:ok, _} = Color.parse("Argb:44;141;255;10")
    end
  end

  describe "parse_list accepts uppercase formats" do
    test "HEX:ff0000|hex:00ff00" do
      assert {:ok, [_, _]} = Color.parse_list("HEX:ff0000|hex:00ff00")
    end
  end

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

  describe "conversiones locales (mismas fórmulas que Pote.Converters)" do
    test "hex 6 y 3 dígitos" do
      assert Color.hex_to_rgb("FF8000") == {255, 128, 0}
      assert Color.hex_to_rgb("F80") == {255, 136, 0}
    end

    test "xterm cubo, grises y estándar" do
      assert Color.xterm_to_rgb(196) == {255, 0, 0}
      assert Color.xterm_to_rgb(232) == {8, 8, 8}
      assert Color.xterm_to_rgb(9) == {255, 0, 0}
      assert Color.xterm_to_rgb(255) == {238, 238, 238}
    end

    test "cmyk" do
      assert Color.cmyk_to_rgb({0, 100, 100, 0}) == {255, 0, 0}
      assert Color.cmyk_to_rgb({100, 0, 0, 0}) == {0, 255, 255}
    end

    test "hsl" do
      assert Color.hsl_to_rgb({0, 100, 50}) == {255, 0, 0}
      assert Color.hsl_to_rgb({120, 100, 25}) == {0, 128, 0}
    end

    test "hsv" do
      assert Color.hsv_to_rgb({0, 100, 100}) == {255, 0, 0}
      assert Color.hsv_to_rgb({240, 100, 100}) == {0, 0, 255}
    end

    test "hwb" do
      assert Color.hwb_to_rgb({0, 0, 0}) == {255, 0, 0}
      assert Color.hwb_to_rgb({0, 100, 0}) == {255, 255, 255}
    end
  end

  describe "autodetección sin prefijo" do
    test "#hex" do
      assert {:ok, {255, 128, 0}} = Color.parse("#FF8000")
      assert {:ok, {255, 136, 0}} = Color.parse("#F80")
    end

    test "entero → xterm" do
      assert {:ok, {255, 0, 0}} = Color.parse("196")
      assert {:ok, {8, 8, 8}} = Color.parse("232")
    end

    test "3 valores sin % → rgb" do
      assert {:ok, {255, 128, 0}} = Color.parse("255,128,0")
      assert {:ok, {255, 128, 0}} = Color.parse("255;128;0")
    end

    test "3 valores con % → hsl" do
      assert {:ok, {255, 0, 0}} = Color.parse("0,100%,50%")
    end

    test "4 valores sin % → argb (alpha ignorado)" do
      assert {:ok, {0, 0, 255}} = Color.parse("255,0,0,255")
    end

    test "4 valores con % → cmyk" do
      assert {:ok, {255, 0, 0}} = Color.parse("0%,100%,100%,0%")
    end

    test "nombres sueltos siguen fallando" do
      assert {:error, msg} = Color.parse("red")
      assert msg =~ "missing format"
    end
  end
end
