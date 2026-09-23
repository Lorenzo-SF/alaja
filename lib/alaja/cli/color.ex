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

  Listas de colores: separadas **SOLO** por `|` (NO por comas):

      db|theme:error|rgb:255;0;0

  El separador `|` separa colores distintos. Las comas (`;` o `,`) solo se
  usan dentro de un color para separar sus componentes (ej: `rgb:255,0,0`).

  `theme:<key>` resuelve un color del tema activo; si la key no existe
  en el tema, se devuelve blanco `{255, 255, 255}` por defecto.

  Las conversiones de espacio de color estan implementadas localmente
  (mismas formulas que `Pote.Converters`), asi este modulo no depende
  del parser del "drawer".
  """

  # The canonical list of formats this module understands. Also reachable
  # through the public `formats/0` and `output_formats/0` functions below,
  # so other modules (e.g. `Alaja.CLI.Commands.Theme`) can iterate it
  # without hardcoding it themselves.
  @formats ~w(rgb argb hex xterm cmyk hsl hsv hwb theme)

  @doc """
  Returns the canonical list of supported input formats.

  Used by both the parser (to validate the `format:` prefix) and
  by the `alaja theme show` table renderer (to enumerate the columns
  dynamically — when a new format lands here it shows up automatically).
  """
  @spec formats() :: [String.t()]
  def formats, do: @formats

  @doc """
  Returns the subset of `formats/0` that make sense as **outputs** of a
  colour (i.e. everything except `theme`, which is a lookup against the
  active theme rather than a serialisation format). Used by `alaja theme
  show` to build the per-format columns of its colour table.
  """
  @spec output_formats() :: [String.t()]
  def output_formats, do: Enum.reject(@formats, &(&1 == "theme"))

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
      [format, code] ->
        format_down = String.downcase(format)

        if format_down in @formats do
          parse_format(format_down, code |> String.trim() |> String.replace(";", ","), str)
        else
          parse_detected(String.replace(str, ";", ","))
        end

      _ ->
        parse_detected(String.replace(str, ";", ","))
    end
  end

  def parse(_), do: nil

  @doc """
  Convenience wrapper: like `parse/1` but unwraps the `{:ok, _}` tag.
  Returns the RGB tuple on success, `nil` on any failure or nil input.
  """
  @spec parse_or_nil(String.t() | nil) :: {0..255, 0..255, 0..255} | nil
  def parse_or_nil(nil), do: nil

  def parse_or_nil(str) when is_binary(str) do
    case parse(str) do
      {:ok, c} -> c
      _ -> nil
    end
  end

  def parse_or_nil(_), do: nil

  @doc """
  Parsea una lista de colores separados por `|`.

  Devuelve `{:ok, [{r,g,b}, ...]}` o `{:error, msg}` acumulando todos
  los colores que fallaron la validacion. `nil` pasa como `nil`.

  Solo `|` es separador entre colores. `;` se reserva como separador
  dentro de valores `rgb:255;0;0` (no estándar — viene de tests
  legacy). Si necesitas `;` como separador entre colores
  explícitamente (p.ej. `--row-N-color` en `alaja table`), usa
  `parse_cell_list/1`.

  ## Ejemplos

      iex> Color.parse_list("rgb:255,0,0|theme:primary")
      {:ok, [{255, 0, 0}, {_, _, _}]}
  """
  @spec parse_list(String.t() | nil) ::
          {:ok, [{0..255, 0..255, 0..255}]} | {:error, String.t()} | nil
  def parse_list(nil), do: nil

  def parse_list(str) when is_binary(str) do
    # List separator is `|`. The `;` form is intentionally NOT
    # accepted here because `;` is also the separator used inside
    # `rgb:255;0;0` style code values in legacy tests/inputs, and
    # accepting it globally would silently mis-parse them.
    #
    # For cellwise colour lists (one RGB per row-N cell, where `;`
    # matches the cell delimiter already used by `alaja table
    # --rows`), use `parse_cell_list/1` below.
    str
    |> String.split("|", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> parse_each()
  end

  def parse_list(_), do: nil

  @doc """
  Convenience wrapper: like `parse_list/1` but unwraps the `{:ok, _}`
  tag. Returns the colour list on success, `nil` on any failure or
  nil input.
  """
  @spec parse_list_or_nil(String.t() | nil) :: [{0..255, 0..255, 0..255}] | nil
  def parse_list_or_nil(nil), do: nil

  def parse_list_or_nil(str) when is_binary(str) do
    case parse_list(str) do
      {:ok, colors} -> colors
      _ -> nil
    end
  end

  def parse_list_or_nil(_), do: nil

  @doc """
  Cellwise colour list — accepts `|` and `;` as separators.

  Use this from contexts where `;` is already the cell delimiter on
  the caller's side (e.g. `alaja table --row-N-color "x;y;z"`), so
  the same syntax lines up with `--rows` and `--row-1-color`. For
  generic colour lists (e.g. `--headers-color`), stick with
  `parse_list/1`, which only accepts `|`.

  Returns `{:ok, [rgb, ...]}` on success, `{:error, msg}` if any
  chunk fails to parse, or `nil` for nil input.
  """
  @spec parse_cell_list(String.t() | nil) ::
          {:ok, [{0..255, 0..255, 0..255}]} | {:error, String.t()} | nil
  def parse_cell_list(nil), do: nil

  def parse_cell_list(str) when is_binary(str) do
    str
    |> String.split("|", trim: true)
    |> Enum.flat_map(fn part -> String.split(part, ";", trim: true) end)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> parse_each()
  end

  def parse_cell_list(_), do: nil

  @doc false
  def normalize_hex("hex", code), do: String.trim_leading(code, "#")
  def normalize_hex(_format, code), do: code

  # ── Formatos explicitos ─────────────────────────────────────────────

  defp parse_format("theme", key, _original) do
    case theme_color(key) do
      nil ->
        {:error,
         "theme color '#{key}' not found in the active theme, in any registered resolver, or in Pote's defaults"}

      rgb ->
        {:ok, rgb}
    end
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

  # Resolve `theme:<key>` against the active theme. Walks the full chain
  # via Pote's resolver stack so:
  #
  #   * keys defined in the *currently active* theme (built-in OR custom)
  #     are resolved directly, with no `to_atom` round-trip;
  #   * keys defined in any other resolver on the stack are picked up as
  #     a side effect of `Pote.resolve_theme_color/1` walking the chain;
  #   * `Pote`'s hardcoded `@default_colors` map is the final fallback.
  #
  # Previously this used `String.to_existing_atom(key) |> Cell.resolve`,
  # which silently returned `nil` for any custom key that wasn't
  # already a known atom (i.e. almost any theme key the user adds
  # beyond the 22 built-in defaults). The bug fell through to the
  # `{255, 255, 255}` white fallback at the call-site, so custom theme
  # keys appeared as invisible white text instead of failing loudly.
  defp theme_color(key) do
    case Alaja.Theme.color(key) do
      {:ok, rgb} ->
        rgb

      :not_found ->
        case Pote.resolve_theme_color(key) do
          {:ok, rgb} -> rgb
          :not_found -> nil
        end
    end
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

  # ── Serialisers (RGB → "<format>:<code>") ──────────────────────────
  #
  # Each format gets its own public `serialize/2` clause plus a
  # private `rgb_to_<format>/1` so the table renderer in
  # `Alaja.CLI.Commands.Theme` can ask for any column without knowing
  # the layout specifics of each format. Inverse of `parse_format/3`.

  @doc """
  Serialises an RGB triple into the `<format>:<code>` string the parser
  accepts on input. Used by `alaja theme show` to build the per-format
  columns of the colour table.

  Currently supports the formats in `output_formats/0` (everything
  except `theme`). Adding a new format requires three pieces:

    1. a `parse_format/3` clause that turns the code into an RGB;
    2. an entry in `@formats` / `formats/0`;
    3. a `serialize/2` clause below that turns an RGB back into it.

  """
  @spec serialize({0..255, 0..255, 0..255}, String.t()) :: String.t()
  def serialize(rgb, "rgb"), do: rgb_to_rgb(rgb)
  def serialize(rgb, "argb"), do: rgb_to_argb(rgb)
  def serialize(rgb, "hex"), do: rgb_to_hex(rgb)
  def serialize(rgb, "xterm"), do: rgb_to_xterm(rgb)
  def serialize(rgb, "cmyk"), do: rgb_to_cmyk(rgb)
  def serialize(rgb, "hsl"), do: rgb_to_hsl(rgb)
  def serialize(rgb, "hsv"), do: rgb_to_hsv(rgb)
  def serialize(rgb, "hwb"), do: rgb_to_hwb(rgb)

  defp rgb_to_rgb({r, g, b}), do: "rgb:#{r},#{g},#{b}"

  # ARGB serialisation assumes opaque alpha (255) by convention; the
  # parser (line 200) drops the alpha too, so round-tripping an ARGB
  # always recovers the RGB regardless of the alpha we put in.
  defp rgb_to_argb({r, g, b}), do: "argb:255,#{r},#{g},#{b}"

  # Pote's `rgb_to_hex/1` returns `"#FF0000"`. The alaja parser strips
  # an optional leading `#` (`normalize_hex/2`), so we emit the form
  # *without* the `#` to keep round-trips identical when the user
  # copies the code back into `alaja ... --color hex:...`.
  defp rgb_to_hex({r, g, b}) do
    hex = String.trim_leading(Pote.Converters.rgb_to_hex({r, g, b}), "#")
    "hex:#{String.upcase(hex)}"
  end

  defp rgb_to_xterm({r, g, b}), do: "xterm:#{Pote.Converters.rgb_to_xterm256({r, g, b})}"

  defp rgb_to_cmyk({r, g, b}) do
    {c, m, y, k} = Pote.Converters.rgb_to_cmyk({r, g, b})
    "cmyk:#{round(c)},#{round(m)},#{round(y)},#{round(k)}"
  end

  defp rgb_to_hsv({r, g, b}) do
    {h, s, v} = Pote.Converters.rgb_to_hsv({r, g, b})
    "hsv:#{round(h)},#{round(s)},#{round(v)}"
  end

  defp rgb_to_hsl({r, g, b}) do
    {h, s, l} = Pote.Converters.rgb_to_hsl({r, g, b})
    "hsl:#{round(h)},#{round(s)},#{round(l)}"
  end

  defp rgb_to_hwb({r, g, b}) do
    {h, w, b_val} = Pote.Converters.rgb_to_hwb({r, g, b})
    "hwb:#{round(h)},#{round(w)},#{round(b_val)}"
  end
end
