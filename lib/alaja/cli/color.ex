defmodule Alaja.CLI.Color do
  @moduledoc """
  Parsing centralizado de colores para el CLI de alaja.

  Formato unico y estricto:

      <formato>:<codigo>

  Formatos soportados: `rgb`, `argb`, `hex` (con o sin `#`), `xterm`,
  `cmyk`, `hsl`, `hsv`, `hwb` y `theme`. Los componentes de un codigo se
  separan con `;` o `,` (se normalizan a `,`).

  Autodeteccion sin prefijo (conveniencia, con las mismas reglas):

      #FF8000        -> hex
      202            -> xterm
      255,128,0      -> rgb
      120,50,50      -> hsl          (si algun valor lleva %)
      255,255,0,0    -> argb
      100,0,50,0     -> cmyk         (si todos los valores llevan %)

  Un nombre suelto (`red`) o un formato desconocido siguen siendo
  invalidos y devuelven `{:error, msg}` con el color literal.

  Listas de colores: separadas por `|`:

      db|theme:error|rgb:255;0;0

  `theme:<key>` resuelve un color del tema activo; si la key no existe
  en el tema, se devuelve blanco `{255, 255, 255}` por defecto.

  Las conversiones de espacio de color estan implementadas localmente
  (mismas formulas que `Pote.Converters`), asi este modulo no depende
  del parser del "drawer".
  """

  @formats ~w(rgb argb hex xterm cmyk hsl hsv hwb theme)

  # ── API publica ────────────────────────────────────────────────────

  @doc """
  Parsea un color a RGB.

  Acepta `<formato>:<codigo>` o la autodeteccion sin prefijo (`#hex`,
  entero xterm, valores separados por coma). Devuelve
  `{:ok, {r, g, b}}` o `{:error, msg}`. `nil` pasa como `nil`.
  """
  @spec parse(String.t() | nil) :: {:ok, {0..255, 0..255, 0..255}} | {:error, String.t()} | nil
  def parse(nil), do: nil

  def parse(str) when is_binary(str) do
    str = String.trim(str)

    case String.split(str, ":", parts: 2) do
      [format, code] when format in @formats ->
        parse_format(format, code |> String.trim() |> String.replace(";", ","), str)

      _ ->
        parse_detected(String.replace(str, ";", ","))
    end
  end

  def parse(_), do: nil

  @doc """
  Parsea una lista de colores separados por `|`.

  Devuelve `{:ok, [{r,g,b}, ...]}` o `{:error, msg}` acumulando todos
  los colores que fallaron la validacion. `nil` pasa como `nil`.
  """
  @spec parse_list(String.t() | nil) ::
          {:ok, [{0..255, 0..255, 0..255}]} | {:error, String.t()} | nil
  def parse_list(nil), do: nil

  def parse_list(str) when is_binary(str) do
    str
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> parse_each()
  end

  def parse_list(_), do: nil

  @doc false
  def normalize_hex("hex", code), do: String.trim_leading(code, "#")
  def normalize_hex(_format, code), do: code

  # ── Formatos explicitos ─────────────────────────────────────────────

  defp parse_format("theme", key, _original) do
    {:ok, theme_color(key) || {255, 255, 255}}
  end

  defp parse_format("hex", code, original) do
    code = normalize_hex("hex", code)

    if String.match?(code, ~r/^[0-9A-Fa-f]{6}$/) or String.match?(code, ~r/^[0-9A-Fa-f]{3}$/) do
      {:ok, hex_to_rgb(code)}
    else
      {:error,
       "invalid color '#{original}': hex value must be 3 or 6 hexadecimal characters. Examples: hex:FF0000, hex:F00"}
    end
  end

  defp parse_format("rgb", code, original) do
    case parse_numbers(code, 3, "rgb values must be three integers 0-255. Example: rgb:255,0,0") do
      {:ok, [r, g, b]} ->
        if r in 0..255 and g in 0..255 and b in 0..255 do
          {:ok, {r, g, b}}
        else
          {:error,
           "invalid color '#{original}': rgb values must be three integers 0-255. Example: rgb:255,0,0"}
        end

      {:error, msg} ->
        {:error, "invalid color '#{original}': #{msg}"}
    end
  end

  defp parse_format("argb", code, original) do
    case parse_numbers(
           code,
           4,
           "argb requires exactly 4 comma-separated values. Example: argb:255,255,0,0"
         ) do
      {:ok, [_a, r, g, b]} ->
        if r in 0..255 and g in 0..255 and b in 0..255 do
          {:ok, {r, g, b}}
        else
          {:error,
           "invalid color '#{original}': argb values must be four integers 0-255 (alpha ignored). Example: argb:255,255,0,0"}
        end

      {:error, msg} ->
        {:error, "invalid color '#{original}': #{msg}"}
    end
  end

  defp parse_format("xterm", code, original) do
    code = String.trim(code)

    case Integer.parse(code) do
      {val, ""} when val in 0..255 ->
        {:ok, xterm_to_rgb(val)}

      _ ->
        {:error,
         "invalid color '#{original}': xterm value must be an integer 0-255. Example: xterm:202"}
    end
  end

  defp parse_format("cmyk", code, original) do
    case parse_floats(
           code,
           4,
           "cmyk requires exactly 4 comma-separated values. Example: cmyk:100,0,50,0"
         ) do
      {:ok, [c, m, y, k]} ->
        if Enum.all?([c, m, y, k], &(&1 >= 0 and &1 <= 100)) do
          {:ok, cmyk_to_rgb({c, m, y, k})}
        else
          {:error,
           "invalid color '#{original}': cmyk values must be C,M,Y,K = 0-100. Example: cmyk:100,0,50,0"}
        end

      {:error, msg} ->
        {:error, "invalid color '#{original}': #{msg}"}
    end
  end

  defp parse_format("hsl", code, original) do
    case parse_floats(
           code,
           3,
           "hsl requires exactly 3 comma-separated values. Example: hsl:120,50,50"
         ) do
      {:ok, [h, s, l]} ->
        if h >= 0 and h <= 360 and s >= 0 and s <= 100 and l >= 0 and l <= 100 do
          {:ok, hsl_to_rgb({h, s, l})}
        else
          {:error,
           "invalid color '#{original}': hsl values must be H=0-360, S=0-100, L=0-100. Example: hsl:120,50,50"}
        end

      {:error, msg} ->
        {:error, "invalid color '#{original}': #{msg}"}
    end
  end

  defp parse_format("hsv", code, original) do
    case parse_floats(
           code,
           3,
           "hsv requires exactly 3 comma-separated values. Example: hsv:120,50,100"
         ) do
      {:ok, [h, s, v]} ->
        if h >= 0 and h <= 360 and s >= 0 and s <= 100 and v >= 0 and v <= 100 do
          {:ok, hsv_to_rgb({h, s, v})}
        else
          {:error,
           "invalid color '#{original}': hsv values must be H=0-360, S=0-100, V=0-100. Example: hsv:120,50,100"}
        end

      {:error, msg} ->
        {:error, "invalid color '#{original}': #{msg}"}
    end
  end

  defp parse_format("hwb", code, original) do
    case parse_floats(
           code,
           3,
           "hwb requires exactly 3 comma-separated values. Example: hwb:120,0.2,0.3"
         ) do
      {:ok, [h, w, b]} ->
        if h >= 0 and h <= 360 and w >= 0 and w <= 1.0 and b >= 0 and b <= 1.0 do
          {:ok, hwb_to_rgb({h, w, b})}
        else
          {:error,
           "invalid color '#{original}': hwb values must be H=0-360, W=0.0-1.0, B=0.0-1.0. Example: hwb:120,0.2,0.3"}
        end

      {:error, msg} ->
        {:error, "invalid color '#{original}': #{msg}"}
    end
  end

  # ── Autodeteccion sin prefijo ───────────────────────────────────────

  defp parse_detected(<<"#", _::binary>> = str) do
    parse_format("hex", normalize_hex("hex", str), str)
  end

  defp parse_detected(str) do
    parts = String.split(str, ",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    case parts do
      [single] ->
        case Integer.parse(single) do
          {val, ""} when val in 0..255 -> parse_format("xterm", single, str)
          _ -> missing_format(str)
        end

      [_, _, _] = three ->
        if Enum.any?(three, &String.contains?(&1, "%")) do
          parse_format("hsl", Enum.map_join(three, ",", &strip_pct/1), str)
        else
          parse_format("rgb", Enum.join(three, ","), str)
        end

      [_, _, _, _] = four ->
        if Enum.all?(four, &String.contains?(&1, "%")) do
          parse_format("cmyk", Enum.map_join(four, ",", &strip_pct/1), str)
        else
          parse_format("argb", Enum.join(four, ","), str)
        end

      _ ->
        missing_format(str)
    end
  end

  defp strip_pct(s), do: String.replace(s, "%", "")

  defp missing_format(str) do
    {:error,
     "invalid color '#{str}': missing format. Use <formato>:<codigo> with formato in #{Enum.join(@formats, ", ")}"}
  end

  defp parse_each(colors) do
    results = Enum.map(colors, &parse/1)

    errors =
      Enum.filter(results, fn
        {:error, _} -> true
        _ -> false
      end)

    case errors do
      [] ->
        {:ok, Enum.map(results, fn {:ok, rgb} -> rgb end)}

      _ ->
        messages = Enum.map_join(errors, "\n", fn {:error, msg} -> "  - #{msg}" end)
        {:error, "Invalid colors in list:\n#{messages}"}
    end
  end

  # ── Helpers de parseo numerico ─────────────────────────────────────

  defp parse_numbers(code, count, full_msg) do
    parts = String.split(code, ",")

    if length(parts) == count do
      parsed =
        parts
        |> Enum.map(&(Integer.parse(String.trim(&1)) |> normalize_parse()))
        |> Enum.reduce_while({:ok, []}, fn
          {:ok, n}, {:ok, acc} -> {:cont, {:ok, [n | acc]}}
          :error, _ -> {:halt, :error}
        end)

      case parsed do
        {:ok, nums} -> {:ok, Enum.reverse(nums)}
        :error -> {:error, full_msg}
      end
    else
      {:error, "requires exactly #{count} comma-separated values"}
    end
  end

  defp parse_floats(code, count, full_msg) do
    parts = String.split(code, ",")

    if length(parts) == count do
      parsed =
        parts
        |> Enum.map(&(Float.parse(String.trim(&1)) |> normalize_float_parse()))
        |> Enum.reduce_while({:ok, []}, fn
          {:ok, n}, {:ok, acc} -> {:cont, {:ok, [n | acc]}}
          :error, _ -> {:halt, :error}
        end)

      case parsed do
        {:ok, nums} -> {:ok, Enum.reverse(nums)}
        :error -> {:error, full_msg}
      end
    else
      {:error, "requires exactly #{count} comma-separated values"}
    end
  end

  defp normalize_parse({n, ""}), do: {:ok, n}
  defp normalize_parse(_), do: :error

  defp normalize_float_parse({n, ""}), do: {:ok, n}
  defp normalize_float_parse(_), do: :error

  # ── Theme ───────────────────────────────────────────────────────────

  defp theme_color(key) do
    String.to_existing_atom(key)
    |> Alaja.Cell.resolve_theme_color()
  rescue
    ArgumentError -> nil
  end

  # ── Conversiones locales (mismas formulas que Pote.Converters) ─────

  @doc false
  def hex_to_rgb(hex) when is_binary(hex) do
    hex = String.replace(hex, "#", "")

    hex =
      if String.length(hex) == 3 do
        hex |> String.graphemes() |> Enum.map_join(&(&1 <> &1))
      else
        hex
      end

    with {:ok, r} <- hex_part_to_int(String.slice(hex, 0, 2)),
         {:ok, g} <- hex_part_to_int(String.slice(hex, 2, 2)),
         {:ok, b} <- hex_part_to_int(String.slice(hex, 4, 2)) do
      {r, g, b}
    else
      _ -> {0, 0, 0}
    end
  end

  defp hex_part_to_int(part) do
    case Integer.parse(part, 16) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end

  @doc false
  def xterm_to_rgb(index) when index in 232..255 do
    gray = (index - 232) * 10 + 8
    {gray, gray, gray}
  end

  def xterm_to_rgb(index) when index in 16..231 do
    index = index - 16
    r = div(index, 36) * 51
    g = div(rem(index, 36), 6) * 51
    b = rem(index, 6) * 51
    {r, g, b}
  end

  def xterm_to_rgb(index) when index in 0..15 do
    colors = [
      {0, 0, 0},
      {128, 0, 0},
      {0, 128, 0},
      {128, 128, 0},
      {0, 0, 128},
      {128, 0, 128},
      {0, 128, 128},
      {128, 128, 128},
      {192, 192, 192},
      {255, 0, 0},
      {0, 255, 0},
      {255, 255, 0},
      {0, 0, 255},
      {255, 0, 255},
      {0, 255, 255},
      {255, 255, 255}
    ]

    Enum.at(colors, index, {0, 0, 0})
  end

  def xterm_to_rgb(_index), do: {0, 0, 0}

  @doc false
  def cmyk_to_rgb({c, m, y, k}) do
    c = c / 100.0
    m = m / 100.0
    y = y / 100.0
    k = k / 100.0

    r = (255.0 * (1.0 - c) * (1.0 - k)) |> round()
    g = (255.0 * (1.0 - m) * (1.0 - k)) |> round()
    b = (255.0 * (1.0 - y) * (1.0 - k)) |> round()

    {r, g, b}
  end

  @doc false
  def hsl_to_rgb({h, s, l}) do
    h = h / 360.0
    s = s / 100.0
    l = l / 100.0

    if s == 0 do
      v = round(l * 255)
      {v, v, v}
    else
      q =
        if l < 0.5 do
          l * (1 + s)
        else
          l + s - l * s
        end

      p = 2 * l - q
      r = hue_to_rgb(p, q, h + 1.0 / 3.0)
      g = hue_to_rgb(p, q, h)
      b = hue_to_rgb(p, q, h - 1.0 / 3.0)

      {round(r * 255), round(g * 255), round(b * 255)}
    end
  end

  defp hue_to_rgb(p, q, t) do
    t =
      cond do
        t < 0 -> t + 1
        t > 1 -> t - 1
        true -> t
      end

    cond do
      t < 1 / 6 -> p + (q - p) * 6 * t
      t < 1 / 2 -> q
      t < 2 / 3 -> p + (q - p) * (2 / 3 - t) * 6
      true -> p
    end
  end

  @doc false
  def hsv_to_rgb({h, s, v}) do
    h = h / 60.0
    s = s / 100.0
    v = v / 100.0
    i = Integer.mod(floor(h), 6)
    f = h - floor(h)
    p = v * (1 - s)
    q = v * (1 - f * s)
    t = v * (1 - (1 - f) * s)

    {r, g, b} =
      case i do
        0 -> {v, t, p}
        1 -> {q, v, p}
        2 -> {p, v, t}
        3 -> {p, q, v}
        4 -> {t, p, v}
        5 -> {v, p, q}
      end

    {round(r * 255), round(g * 255), round(b * 255)}
  end

  @doc false
  def hwb_to_rgb({h, w, b}) do
    if w + b >= 1.0 do
      gray = if w + b == 0.0, do: 0, else: round(w / (w + b) * 255)
      {gray, gray, gray}
    else
      {r, g, b_val} = hsv_to_rgb({h, 100.0, 100.0})
      r = r / 255.0
      g = g / 255.0
      b_val = b_val / 255.0
      factor = 1.0 - w - b
      r = r * factor + w
      g = g * factor + w
      b_val = b_val * factor + w

      {round(r * 255), round(g * 255), round(b_val * 255)}
    end
  end
end
