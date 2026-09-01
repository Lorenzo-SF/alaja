defmodule Alaja.Components.ColorWheel.Info do
  @moduledoc false

  alias Alaja
  alias Alaja.ANSI
  alias Alaja.Components.ColorWheel.Harmonies, as: ColorHarmonies
  alias Alaja.Components.ColorWheel.Renderer

  alias Pote
  alias Pote.Converters

  @type rgb :: Pote.rgb()
  @type color_input :: rgb() | String.t()

  @doc """
  Displays detailed color information: swatch, formats, and optional variants.
  """
  @spec show_color_info(color_input(), keyword()) :: :ok
  def show_color_info(color, opts \\ []) do
    show_formats = Keyword.get(opts, :show_formats, true)
    show_variants = Keyword.get(opts, :show_variants, false)

    rgb = resolve_rgb(color)
    {r, g, b} = rgb

    IO.puts("#{Alaja.ANSI.fg(r, g, b)}  ████████████████████#{ANSI.reset_attributes()}")

    IO.puts("")

    if show_formats, do: render_color_formats(rgb)
    if show_variants, do: render_color_variants(rgb)

    :ok
  end

  @doc """
  Shows a harmony ring using ASCII rendering with autodetection of terminal
  capabilities. Falls back to ASCII half-block when the terminal does not
  support native image protocols.
  """
  @spec show_harmony_ring(color_input(), atom(), keyword()) :: :ok
  def show_harmony_ring(base_color, harmony_type \\ :triad, opts \\ []) do
    base_rgb = resolve_rgb(base_color)
    colors = ColorHarmonies.compute_harmony(base_rgb, harmony_type)
    harmony_name = ColorHarmonies.harmony_display_name(harmony_type)

    IO.puts("  #{ANSI.bold_on()}🎨 #{harmony_name}#{ANSI.reset_attributes()}\n")

    angles = ColorHarmonies.extract_angles([base_rgb | colors])
    lines = Renderer.get_ascii_wheel_lines(angles, harmony_type, opts)
    Enum.each(lines, &IO.puts("  " <> &1))

    IO.puts("")
    render_swatch_list([base_rgb | colors])
    :ok
  end

  @doc """
  Shows a list of colors as linear swatches.
  """
  @spec show_swatches([color_input()], keyword()) :: :ok
  def show_swatches(colors, opts \\ []) do
    per_row = Keyword.get(opts, :per_row, 4)

    colors
    |> Enum.map(&resolve_rgb/1)
    |> Enum.chunk_every(per_row)
    |> Enum.each(fn chunk ->
      line =
        Enum.map_join(chunk, "  ", fn {r, g, b} ->
          hex = Converters.rgb_to_hex({r, g, b})
          "#{Alaja.ANSI.fg(r, g, b)}████████#{ANSI.reset_attributes()} #{hex}"
        end)

      IO.puts("  #{line}")
    end)

    :ok
  end

  @doc """
  Shows a horizontal gradient between two colors.
  """
  @spec show_gradient(color_input(), color_input(), pos_integer()) :: :ok
  def show_gradient(start_color, end_color, steps \\ 20) do
    start_rgb = resolve_rgb(start_color)
    end_rgb = resolve_rgb(end_color)

    gradient =
      Enum.map_join(0..(steps - 1), fn i ->
        factor = i / max(steps - 1, 1)
        {r, g, b} = blend(start_rgb, end_rgb, factor)
        "#{Alaja.ANSI.fg(r, g, b)}██#{ANSI.reset_attributes()}"
      end)

    IO.puts("  #{gradient}")
    :ok
  end

  @doc """
  Renders color format information as formatted terminal output.
  """
  @spec render_color_formats(rgb()) :: :ok
  def render_color_formats({r, g, b} = rgb) do
    hex = Converters.rgb_to_hex(rgb)
    {h, s, l} = Converters.rgb_to_hsl(rgb)
    {hv, sv, v} = Converters.rgb_to_hsv(rgb)
    {c, m, y, k} = Converters.rgb_to_cmyk(rgb)
    xterm = Converters.rgb_to_xterm256(rgb)
    argb = {255, r, g, b}

    formats = [
      {"HEX", hex},
      {"RGB", "{#{r}, #{g}, #{b}}"},
      {"ARGB", "{#{elem(argb, 0)}, #{elem(argb, 1)}, #{elem(argb, 2)}, #{elem(argb, 3)}}"},
      {"HSL", "{#{Float.round(h, 1)}°, #{Float.round(s, 1)}%, #{Float.round(l, 1)}%}"},
      {"HSV", "{#{Float.round(hv, 1)}°, #{Float.round(sv, 1)}%, #{Float.round(v, 1)}%}"},
      {"CMYK",
       "{#{Float.round(c, 1)}%, #{Float.round(m, 1)}%, #{Float.round(y, 1)}%, #{Float.round(k, 1)}%}"},
      {"XTerm256", "#{xterm}"}
    ]

    Enum.each(formats, fn {label, value} ->
      IO.puts(
        "  #{Alaja.ANSI.fg(r, g, b)}#{String.pad_trailing(label, 10)}#{ANSI.reset_attributes()} #{value}"
      )
    end)

    IO.puts("")
    :ok
  end

  @doc """
  Shows lighter/darker variants of a color.
  """
  @spec render_color_variants(rgb()) :: :ok
  def render_color_variants(rgb) do
    variants = [
      {"+50%", Pote.Harmonies.lighter(rgb, 0.5)},
      {"+20%", Pote.Harmonies.lighter(rgb, 0.2)},
      {"Base", rgb},
      {"-20%", Pote.Harmonies.darker(rgb, 0.2)},
      {"-50%", Pote.Harmonies.darker(rgb, 0.5)}
    ]

    line =
      Enum.map_join(variants, "  ", fn {label, {r, g, b}} ->
        "#{Alaja.ANSI.fg(r, g, b)}████#{ANSI.reset_attributes()} #{label}"
      end)

    IO.puts("  #{line}")
    IO.puts("")
    :ok
  end

  @doc """
  Renders a list of color swatches with hex labels.
  """
  @spec render_swatch_list([rgb()]) :: :ok
  def render_swatch_list(colors) do
    Enum.each(colors, fn {r, g, b} = rgb ->
      hex = Converters.rgb_to_hex(rgb)

      IO.puts(
        "  #{Alaja.ANSI.fg(r, g, b)}████#{ANSI.reset_attributes()} #{hex}  rgb(#{r},#{g},#{b})"
      )
    end)

    :ok
  end

  @spec resolve_rgb(color_input()) :: rgb()
  defp resolve_rgb(input) when is_tuple(input) and tuple_size(input) == 3, do: input

  defp resolve_rgb(input) when is_binary(input) do
    case Alaja.CLI.Color.parse(input) do
      {:ok, rgb} -> rgb
      _ -> {255, 255, 255}
    end
  end

  defp resolve_rgb(_), do: {255, 255, 255}

  @spec blend(rgb(), rgb(), float()) :: rgb()
  defp blend({r1, g1, b1}, {r2, g2, b2}, factor) do
    r = round(r1 + (r2 - r1) * factor)
    g = round(g1 + (g2 - g1) * factor)
    b = round(b1 + (b2 - b1) * factor)
    {min(max(r, 0), 255), min(max(g, 0), 255), min(max(b, 0), 255)}
  end
end
