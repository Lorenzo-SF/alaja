defmodule Alaja.CLI.Color do
  @moduledoc """
  Parsing centralizado de colores para el CLI de alaja.

  Todos los comandos que reciben colores pasan por aqui, con un formato
  unico y estricto:

      <formato>:<codigo>

  Formatos soportados: `rgb`, `argb`, `hex` (con o sin `#`), `xterm`,
  `cmyk`, `hsl`, `hsv`, `hwb` y `theme`. Los componentes de un codigo se
  separan con `;` o `,` (se normalizan a `,` antes de delegar en Pote).

  Listas de colores: separadas por `|`:

      db|theme:error|rgb:255;0;0

  `theme:<key>` resuelve un color del tema activo; si la key no existe
  en el tema, se devuelve blanco `{255, 255, 255}` por defecto.

  Errores: `{:error, msg}` donde `msg` incluye el color literal que no
  paso la validacion.
  """

  @formats ~w(rgb argb hex xterm cmyk hsl hsv hwb theme)

  @doc """
  Parsea un color en formato `<formato>:<codigo>`.

  Devuelve `{:ok, {r, g, b}}` o `{:error, msg}`. `nil` pasa como `nil`.
  """
  @spec parse(String.t() | nil) :: {:ok, {0..255, 0..255, 0..255}} | {:error, String.t()} | nil
  def parse(nil), do: nil

  def parse(str) when is_binary(str) do
    str = String.trim(str)

    case String.split(str, ":", parts: 2) do
      [format, code] when format in @formats ->
        parse_format(format, String.trim(code), str)

      _ ->
        {:error,
         "invalid color '#{str}': missing format. Use <formato>:<codigo> with formato in #{Enum.join(@formats, ", ")}"}
    end
  end

  def parse(_), do: nil

  @doc """
  Parsea una lista de colores separados por `|`.

  Devuelve `{:ok, [{r,g,b}, ...]}` o `{:error, msg}` indicando el primer
  color que fallo la validacion. `nil` pasa como `nil`.
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

  # ── Formatos ──────────────────────────────────────────────────────

  defp parse_format("theme", key, _original) do
    rgb = theme_color(key)
    {:ok, rgb || {255, 255, 255}}
  end

  defp parse_format(format, code, original) do
    normalized = String.replace(code, ";", ",")
    normalized = normalize_hex(format, normalized)

    case Pote.Orchestrator.parse_color("#{format}:#{normalized}") do
      {:ok, _rgb} = ok ->
        ok

      {:error, reason} ->
        {:error, "invalid color '#{original}': #{reason}"}
    end
  end

  @doc false
  def normalize_hex("hex", code), do: String.trim_leading(code, "#")
  def normalize_hex(_format, code), do: code

  defp theme_color(key) do
    try do
      String.to_existing_atom(key)
      |> Alaja.Cell.resolve_theme_color()
    rescue
      ArgumentError -> nil
    end
  end
end