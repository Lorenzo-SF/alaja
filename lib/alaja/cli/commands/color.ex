# credo:disable-for-this-file Credo.Check.Readability.StringSigils
defmodule Alaja.CLI.Commands.Color do
  @moduledoc """
  `alaja color` — Color analysis, harmonies, conversions, and tone manipulation.

  Parses a color in any supported format and displays its values across
  multiple colour spaces (HEX, RGB, HSL, HSV, CMYK, XTerm256, CIELAB,
  CIE XYZ), generates colour harmonies, computes WCAG contrast ratios,
  and renders a visual colour wheel when possible.
  """

  @help_data [
    title: "Alaja Color",
    subtitle: "Color analysis, harmonies, conversions, and tone manipulation",
    usage:
      "alaja color <color> [--harmony TYPE] [--darken N] [--lighten N] [--lab] [--xyz] [--kelvin] [--pantone] [--contrast C]",
    description: """
    Parses a colour in any supported format and displays its values across
    multiple colour spaces (HEX, RGB, HSL, HSV, CMYK, XTerm256, CIELAB,
    CIE XYZ), generates colour harmonies, computes WCAG contrast ratios,
    and renders a visual colour wheel when possible.

    Accepted colour formats: hex:#RRGGBB, rgb:R;G;B, hsl:H;S;L, hsv:H;S;V,
    cmyk:C;M;Y;K, xterm:N, theme:<key>.
    """,
    options: [
      {:harmony, :string, nil,
       "Generate colour harmonies: triad, complementary, analogous, square, monochromatic, compound, split-complementary"},
      {:darken, :integer, nil, "Darken by N steps before displaying"},
      {:lighten, :integer, nil, "Lighten by N steps before displaying"},
      {:lab, :boolean, false, "Include CIELAB values"},
      {:xyz, :boolean, false, "Include CIE XYZ values"},
      {:kelvin, :boolean, false, "Include colour temperature in Kelvin"},
      {:pantone, :boolean, false, "Include Pantone approximation"},
      {:contrast, :string, nil, "Compute WCAG contrast ratio against this colour"}
    ],
    examples: [
      {"Plain colour info", "alaja color hex:ff6b6b"},
      {"Triad harmonies", "alaja color hex:ff6b6b --harmony triad"},
      {"Darken a brand colour", "alaja color hex:4ecdc4 --darken 3"},
      {"CIELAB values", "alaja color hex:1e1e2e --lab"},
      {"Contrast check (WCAG)", "alaja color hex:1e1e2e --contrast hex:cdd6f4"},
      {"From theme key", "alaja color theme:primary"},
      {"Full report", "alaja color rgb:255;87;51 --lab --xyz --kelvin --pantone"}
    ]
  ]

  alias Alaja.Buffer
  alias Alaja.CLI.GlobalOpts
  alias Alaja.Components.ColorWheel
  alias Alaja.Components.Table, as: TableComp
  alias Alaja.Printer
  alias Pote.Converters.Advanced
  alias Pote.Converters.RGB, as: RGBConverter
  alias Pote.Harmonies

  @harmony_types %{
    "triad" => :triad,
    "complementary" => :complementary,
    "analogous" => :analogous,
    "square" => :square,
    "monochromatic" => :monochromatic,
    "compound" => :compound,
    "split-complementary" => :split_complementary
  }

  @doc """
  Runs the `alaja color` command.
  """
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    {global, rest} = GlobalOpts.parse(args)

    {opts, positional, _} =
      OptionParser.parse(rest,
        switches: [
          harmony: :string,
          darken: :integer,
          lighten: :integer,
          lab: :boolean,
          xyz: :boolean,
          kelvin: :boolean,
          pantone: :boolean,
          contrast: :string
        ]
      )

    if global.help do
      help()
    else
      analyze_or_help(positional, opts, global)
    end
  end

  defp analyze_or_help([color_str | _], opts, global) do
    analyze(color_str, opts, global)
  end

  defp analyze_or_help([], _opts, _global) do
    help()
  end

  # ─── Analyze mode ─────────────────────────────────────────────────────────

  defp analyze(color_str, opts, global) do
    case Alaja.CLI.Color.parse(color_str) do
      {:ok, rgb} ->
        rgb = apply_tone(rgb, opts)

        if global.verbose do
          output_raw_json(rgb)
        else
          output = build_color_analysis(rgb, opts)
          Printer.print_raw(output, printer_opts(global))
        end

      {:error, msg} ->
        IO.puts(:stderr, "Error: #{msg}")
        exit({:shutdown, 1})
    end
  end

  defp apply_tone(rgb, opts) do
    rgb =
      case Keyword.get(opts, :darken) do
        n when is_integer(n) and n >= 1 and n <= 10 ->
          Harmonies.darker(rgb, n * 0.1)

        _ ->
          rgb
      end

    case Keyword.get(opts, :lighten) do
      n when is_integer(n) and n >= 1 and n <= 10 ->
        Harmonies.lighter(rgb, n * 0.1)

      _ ->
        rgb
    end
  end

  defp output_raw_json(rgb) do
    data = build_color_data(rgb)

    case Jason.encode(data, pretty: true) do
      {:ok, json} -> IO.puts(json)
      {:error, _} -> IO.puts("{}")
    end
  end

  defp build_color_analysis(rgb, opts) do
    base_hex = RGBConverter.to_hex(rgb)
    {r, g, b} = rgb
    harmony_type = get_harmony_type(opts)
    harmony_colors = get_harmony_colors(rgb, harmony_type)
    all_colors = [rgb | harmony_colors]
    col_names = get_column_names(harmony_type)
    harmony_name = ColorWheel.harmony_display_name(harmony_type || :base)

    title_label = if harmony_type, do: "🎨 #{harmony_name}", else: "🎨 #{base_hex}"

    title =
      "#{Alaja.ANSI.fg(r, g, b)}#{Alaja.ANSI.bold_on()}#{title_label}#{Alaja.ANSI.reset_attributes()}\n\n"

    wheel = render_color_wheel_output(all_colors)

    table =
      rgb
      |> build_color_table(all_colors, col_names)
      |> Buffer.to_iodata()

    extras = collect_extras(rgb, opts)

    extras_part =
      if extras != [] do
        extra_rows = extras
        extra_headers = ["Property", "Value"]

        extra_table =
          [extra_headers | extra_rows]
          |> TableComp.render(
            table_border: :rounded,
            padding: 1,
            border_color: rgb,
            table_align: :left
          )
          |> Buffer.to_iodata()

        ["\n", extra_table]
      else
        []
      end

    variants_part =
      if Keyword.has_key?(opts, :darken) or Keyword.has_key?(opts, :lighten) do
        render_variants_string(rgb)
      else
        []
      end

    [title, table, variants_part, "\n", extras_part, "\n", wheel]
  end

  defp get_harmony_type(opts) do
    case Keyword.get(opts, :harmony) do
      nil -> nil
      type_str -> Map.get(@harmony_types, type_str)
    end
  end

  defp get_harmony_colors(_rgb, nil), do: []

  defp get_harmony_colors(rgb, harmony_type) do
    ColorWheel.compute_harmony(rgb, harmony_type)
  end

  defp get_column_names(nil), do: ["Base"]
  defp get_column_names(:triad), do: ["Base", "Tertiary", "Secondary"]
  defp get_column_names(:complementary), do: ["Base", "Complementary"]
  defp get_column_names(:analogous), do: ["Base", "Analogous₁", "Analogous₂"]
  defp get_column_names(:square), do: ["Base", "Square₁", "Square₂", "Square₃"]
  defp get_column_names(:monochromatic), do: ["Base", "Mono₁", "Mono₂", "Mono₃", "Mono₄"]
  defp get_column_names(:compound), do: ["Base", "Compound₁", "Compound₂"]
  defp get_column_names(:split_complementary), do: ["Base", "Split₁", "Split₂"]

  defp render_color_wheel_output(colors) do
    png_data = ColorWheel.render_png_wheel(colors)
    rendered = IO.iodata_to_binary(png_data)

    if rendered != "" do
      rendered
    else
      angles = ColorWheel.extract_angles(colors)
      lines = ColorWheel.get_ascii_wheel_lines(angles, :custom, [])
      Enum.map(lines, fn line -> ["  ", line, "\n"] end)
    end
  end

  defp build_color_table(_base_rgb, all_colors, col_names) do
    property_rows = build_property_rows(all_colors)
    headers = ["Property" | col_names]

    table_opts = [
      table_border: :rounded,
      padding: 1,
      border_color: {255, 255, 255},
      table_align: :left,
      headers_color: [nil | all_colors],
      headers_effects: [:bold]
    ]

    TableComp.render([headers | property_rows], table_opts)
  end

  defp build_property_rows(colors) do
    [
      build_row("Hex", colors, fn c -> RGBConverter.to_hex(c) end),
      build_row("RGB", colors, fn {r, g, b} -> "#{r}, #{g}, #{b}" end),
      build_row("ARGB", colors, fn {r, g, b} -> "255, #{r}, #{g}, #{b}" end),
      build_row("HSL", colors, &format_hsl/1),
      build_row("HSV", colors, &format_hsv/1),
      build_row("CMYK", colors, &format_cmyk/1),
      build_row("XTerm", colors, fn c -> to_string(RGBConverter.to_xterm256(c)) end),
      build_row("Luminance", colors, &format_luminance/1),
      build_row("Pantone", colors, &format_pantone/1),
      build_row("Swatch", colors, fn {r, g, b} ->
        "#{Alaja.ANSI.bg(r, g, b)}        #{Alaja.ANSI.reset_attributes()}"
      end)
    ]
  end

  defp build_row(label, colors, formatter) do
    [label | Enum.map(colors, formatter)]
  end

  defp collect_extras(rgb, opts) do
    []
    |> add_extras(rgb, opts, :lab, fn ->
      {l, a, b_val} = Advanced.to_lab(rgb)
      "L: #{l}, a: #{a}, b: #{b_val}"
    end)
    |> add_extras(rgb, opts, :xyz, fn ->
      {x, y, z} = Advanced.to_xyz(rgb)
      "X: #{x}, Y: #{y}, Z: #{z}"
    end)
    |> add_extras(rgb, opts, :kelvin, fn ->
      case Advanced.rgb_to_kelvin(rgb) do
        nil -> "N/A"
        k -> "#{k}K"
      end
    end)
    |> add_extras(rgb, opts, :pantone, fn ->
      case Advanced.nearest_pantone(rgb) do
        nil -> "N/A"
        {name, dist} -> "#{name} (ΔE #{Float.round(dist, 1)})"
      end
    end)
    |> add_contrast(rgb, opts)
  end

  defp add_extras(acc, _rgb, opts, key, fun) do
    if Keyword.get(opts, key, false) do
      acc ++ [[String.upcase(to_string(key)), fun.()]]
    else
      acc
    end
  end

  defp add_contrast(acc, rgb, opts) do
    case Keyword.get(opts, :contrast) do
      nil ->
        acc

      other_str ->
        case Alaja.CLI.Color.parse(other_str) do
          {:ok, other_rgb} ->
            ratio = Advanced.contrast_ratio(rgb, other_rgb)
            de = Advanced.delta_e(rgb, other_rgb)

            acc ++
              [
                ["WCAG Ratio", Float.round(ratio, 2)],
                ["Delta E", Float.round(de, 2)]
              ]

          {:error, msg} ->
            IO.puts(:stderr, "  Error parsing contrast color: #{msg}")
            acc
        end
    end
  end

  defp render_variants_string(rgb) do
    variants = [
      {"+50%", Harmonies.lighter(rgb, 0.5)},
      {"+20%", Harmonies.lighter(rgb, 0.2)},
      {"Base", rgb},
      {"-20%", Harmonies.darker(rgb, 0.2)},
      {"-50%", Harmonies.darker(rgb, 0.5)}
    ]

    line =
      Enum.map_join(variants, "  ", fn {label, {vr, vg, vb}} ->
        "#{Alaja.ANSI.fg(vr, vg, vb)}████#{Alaja.ANSI.reset_attributes()} #{label}"
      end)

    ["\n  ", line, "\n"]
  end

  # ─── Format helpers ───────────────────────────────────────────────────────

  defp format_hsl({r, g, b}) do
    {h, s, l} = RGBConverter.to_hsl({r, g, b})
    "#{Float.round(h, 1)}° #{Float.round(s, 1)}% #{Float.round(l, 1)}%"
  end

  defp format_hsv({r, g, b}) do
    {h, s, v} = RGBConverter.to_hsv({r, g, b})
    "#{Float.round(h, 1)}° #{Float.round(s, 1)}% #{Float.round(v, 1)}%"
  end

  defp format_cmyk({r, g, b}) do
    {c, m, y, k} = RGBConverter.to_cmyk({r, g, b})
    "#{Float.round(c, 1)}% #{Float.round(m, 1)}% #{Float.round(y, 1)}% #{Float.round(k, 1)}%"
  end

  defp format_pantone({r, g, b}) do
    case Advanced.nearest_pantone({r, g, b}) do
      nil -> "N/A"
      {name, _dist} -> name
    end
  end

  defp format_luminance({r, g, b}) do
    Float.round(Advanced.relative_luminance({r, g, b}), 4)
  end

  defp build_color_data(rgb) do
    {r, g, b} = rgb
    {h, s, l} = RGBConverter.to_hsl(rgb)
    {hv, sv, v} = RGBConverter.to_hsv(rgb)
    {c, m, y, k} = RGBConverter.to_cmyk(rgb)
    {lx, la, lb} = Advanced.to_lab(rgb)
    {x, yz, z} = Advanced.to_xyz(rgb)

    %{
      hex: RGBConverter.to_hex(rgb),
      rgb: [r, g, b],
      argb: [255, r, g, b],
      hsl: %{h: Float.round(h, 1), s: Float.round(s, 1), l: Float.round(l, 1)},
      hsv: %{h: Float.round(hv, 1), s: Float.round(sv, 1), v: Float.round(v, 1)},
      cmyk: %{
        c: Float.round(c, 1),
        m: Float.round(m, 1),
        y: Float.round(y, 1),
        k: Float.round(k, 1)
      },
      xterm: RGBConverter.to_xterm256(rgb),
      lab: %{l: Float.round(lx, 2), a: Float.round(la, 2), b: Float.round(lb, 2)},
      xyz: %{x: Float.round(x, 3), y: Float.round(yz, 3), z: Float.round(z, 3)},
      luminance: Float.round(Advanced.relative_luminance(rgb), 4)
    }
  end

  defp printer_opts(g), do: GlobalOpts.to_printer_opts(g)

  # ─── Help ─────────────────────────────────────────────────────────────────

  @doc """
  Prints help for the `alaja color` command.
  """
  @spec help(Alaja.CLI.GlobalOpts.t() | nil) :: :ok
  def help(global \\ nil), do: Alaja.CLI.HelpFormatter.render(@help_data, global)
end
