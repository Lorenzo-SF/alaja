defmodule Alaja.Components.ColorWheel do
  alias Alaja.Buffer
  alias Alaja.Components.ColorWheel.{Harmonies, Info, Renderer}

  alias Pote
  alias Pote.Orchestrator

  @moduledoc """
  Color visualization component for the terminal.

  Provides multiple rendering modes:

  - **Native image** (Kitty/iTerm2/Sixel): generates a real bitmap of the color
    wheel using the detected terminal protocol, with the harmony colours
    marked at their hue position.
  - **ASCII half-block** (universal fallback): renders a circle using Unicode
    `▀`/`▄` characters with true-color ANSI (24-bit), yielding 2 pixels per
    vertical cell. This is the Buffer-first canonical rendering.

  The canonical entry point is `render/2`, which returns an
  `Alaja.Buffer.t/0`. Callers that want native-image output should
  use `render_for_terminal/2` (returns a tagged value so the caller
  decides whether to embed the bytes directly or feed a Buffer to
  the printer).

  ## Contracts

  Este módulo usa los tipos definidos en `Pote` como fuente canónica.

  ## Examples

      alias Alaja.Components.ColorWheel

      # Canonical Buffer-first render (works in any terminal)
      buffer = ColorWheel.render([{255, 0, 0}, {0, 255, 0}], harmony: :triad)
      Alaja.Printer.print_raw(buffer)

      # Native image when supported, ASCII fallback otherwise
      case ColorWheel.render_for_terminal([{255, 0, 0}], harmony: :triad) do
        {:image, iodata} -> IO.write(iodata)
        {:ascii, buffer} -> Alaja.Printer.print_raw(buffer)
      end

      # Legacy IO-based helpers (deprecated but still work)
      ColorWheel.show_color_info({255, 87, 51})
      ColorWheel.show_harmony_ring({255, 0, 0}, :triad)
      ColorWheel.show_swatches([{255, 0, 0}, {0, 255, 0}, {0, 0, 255}])

  """

  @type rgb :: Pote.rgb()

  @doc """
  Canonical Buffer-first render entry point.

  Returns an `Alaja.Buffer.t/0` containing the colour wheel drawn with
  Unicode half-block characters (▀/▄) at the requested harmony colours'
  hue positions. The buffer is sized `4*radius+1` cells wide by `radius`
  cells tall, where the x-scale of 2.0 makes the wheel appear circular
  on terminals whose cells are taller than wide.

  ## Options

    - `:radius` — wheel radius in cells (default: 10)
    - `:thickness` — ring thickness as a fraction of the radius (default: 0.4)
    - `:harmony` — atom for the harmony type, draws the marker label in
                   the centre (`:triad`, `:complementary`, etc.)
    - `:harmony_angles` — explicit list of hue angles to mark (overrides
                          `:harmony` for the marker positions)

  When `:harmony` is set, a centred label is embedded in the centre row
  using a white-on-black pill. When `:harmony_angles` is set, no label is
  drawn (the wheel is "unlabelled").
  """
  @spec render([rgb()], keyword()) :: Buffer.t()
  def render(rgb_list, opts \\ []), do: Renderer.render(rgb_list, opts)

  @doc """
  Render the wheel using the best protocol for the current terminal.

  Returns:
    * `{:image, iodata}` — when the terminal supports native images
      (Kitty, iTerm2, Sixel); `iodata` contains the terminal escape codes
      for an inline PNG with the wheel and harmony markers.
    * `{:ascii, Buffer.t()}` — otherwise; the Buffer can be passed to
      `Alaja.Printer.print_raw/2`.

  The caller dispatches on the tag because PNG escapes cannot be embedded
  in a Buffer cell — they have to be written directly to stdout by the
  caller.
  """
  @spec render_for_terminal([rgb()], keyword()) ::
          {:image, iodata()} | {:ascii, Buffer.t()}
  def render_for_terminal(rgb_list, opts \\ []), do: Renderer.render_for_terminal(rgb_list, opts)

  @doc """
  Returns the default options for the wheel renderer.
  """
  @spec default_opts() :: keyword()
  def default_opts, do: Renderer.default_opts()

  @doc """
  Displays detailed color information: swatch, formats, and optional variants.
  """
  @spec show_color_info(Orchestrator.color_input(), keyword()) :: :ok
  def show_color_info(color, opts \\ []), do: Info.show_color_info(color, opts)

  @doc """
  Shows a harmony ring using ASCII rendering with autodetection of terminal
  capabilities. Falls back to ASCII half-block when the terminal does not
  support native image protocols.
  """
  @spec show_harmony_ring(Orchestrator.color_input(), atom(), keyword()) :: :ok
  def show_harmony_ring(base_color, harmony_type \\ :triad, opts \\ []),
    do: Info.show_harmony_ring(base_color, harmony_type, opts)

  @doc """
  Shows a list of colors as linear swatches.
  """
  @spec show_swatches([Orchestrator.color_input()], keyword()) :: :ok
  def show_swatches(colors, opts \\ []), do: Info.show_swatches(colors, opts)

  @doc """
  Shows a horizontal gradient between two colors.
  """
  @spec show_gradient(Orchestrator.color_input(), Orchestrator.color_input(), pos_integer()) ::
          :ok
  def show_gradient(start_color, end_color, steps \\ 20),
    do: Info.show_gradient(start_color, end_color, steps)

  @doc """
  Renders the ASCII color wheel and returns the lines (for layout composition).
  """
  @spec get_ascii_wheel_lines([number()], atom(), keyword()) :: [String.t()]
  def get_ascii_wheel_lines(harmony_angles, harmony_type, opts \\ []),
    do: Renderer.get_ascii_wheel_lines(harmony_angles, harmony_type, opts)

  @doc """
  Computes the harmony colors for a given type and base RGB.
  """
  @spec compute_harmony(rgb(), atom()) :: [rgb()]
  def compute_harmony(rgb, harmony_type), do: Harmonies.compute_harmony(rgb, harmony_type)

  @doc """
  Extracts HSL hue angles from a list of RGB tuples.
  """
  @spec extract_angles([rgb()]) :: [number()]
  def extract_angles(rgbs), do: Harmonies.extract_angles(rgbs)

  @doc """
  Renders color format information as formatted terminal output.
  """
  @spec render_color_formats(rgb()) :: :ok
  def render_color_formats(rgb), do: Info.render_color_formats(rgb)

  @doc """
  Shows lighter/darker variants of a color.
  """
  @spec render_color_variants(rgb()) :: :ok
  def render_color_variants(rgb), do: Info.render_color_variants(rgb)

  @doc """
  Renders a list of color swatches with hex labels.
  """
  @spec render_swatch_list([rgb()]) :: :ok
  def render_swatch_list(colors), do: Info.render_swatch_list(colors)

  @doc """
  Returns the Spanish display name for a harmony type.
  """
  @spec harmony_display_name(atom()) :: String.t()
  def harmony_display_name(harmony_type), do: Harmonies.harmony_display_name(harmony_type)

  @doc """
  Renders the color wheel as a PNG image and prints it to the terminal.

  This function generates a bitmap of the color wheel with harmony markers
  and outputs it using the detected image protocol (Kitty/iTerm2/Sixel).

  ## Parameters

    - `rgb_list` - List of RGB tuples representing colors to mark on the wheel
    - `opts` - Options (same as `get_ascii_wheel_lines`)
  """
  @spec render_png_wheel([rgb()], keyword()) :: iodata()
  def render_png_wheel(rgb_list, opts \\ []), do: Renderer.render_png_wheel(rgb_list, opts)
end
