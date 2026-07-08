defmodule Alaja.Cell do
  @moduledoc """
  Atomic visual unit for the terminal buffer.

  A cell holds a single character, optional foreground/background RGB
  colours, and a list of text effects (bold, italic, underline, etc.).

  All operations return new cells — no mutation. Colours can be RGB
  tuples, Pote theme atoms (resolved at ANSI-build time), or `nil`.
  """

  @type effect ::
          :bold
          | :italic
          | :underline
          | :strikethrough
          | :reverse
          | :blink
          | :hidden
          | :dim

  @type color :: {0..255, 0..255, 0..255} | atom() | nil

  @type effects :: [effect()]

  @type t :: %__MODULE__{
          char: String.t(),
          fg: color(),
          bg: color(),
          effects: effects()
        }

  defstruct char: " ", fg: nil, bg: nil, effects: []

  @doc """
  Creates a new cell with the given character and optional colors.

  ## Parameters

  - `char` - The character to display (default: `" "`)
  - `opts` - Optional keyword list for foreground, background and effects.
  - `fg` - Foreground color as `{r, g, b}` tuple or atom (default: `nil`)
  - `bg` - Background color as `{r, g, b}` tuple or atom (default: `nil`)

  ## Examples

      iex> Cell.new("A", {255, 0, 0}, {0, 255, 0})
      %Cell{char: "A", fg: {255, 0, 0}, bg: {0, 255, 0}, effects: []}

      iex> Cell.new("★", {255, 215, 0}, nil, effects: [:bold])
      %Cell{char: "★", fg: {255, 215, 0}, bg: nil, effects: [:bold]}
  """
  @spec new(String.t(), color() | keyword(), color(), keyword()) :: t()
  def new(char \\ " ", fg_or_opts \\ nil, bg \\ nil, opts \\ [])

  def new(char, opts, nil, []) when is_list(opts) do
    do_new(char, Keyword.get(opts, :fg), Keyword.get(opts, :bg), opts)
  end

  def new(char, fg, bg, opts) do
    do_new(char, fg, bg, opts)
  end

  defp do_new(char, fg, bg, opts) do
    base_effects = Keyword.get(opts, :effects, [])

    effects =
      base_effects ++
        if(Keyword.get(opts, :bold), do: [:bold], else: []) ++
        if(Keyword.get(opts, :dim), do: [:dim], else: []) ++
        if(Keyword.get(opts, :italic), do: [:italic], else: []) ++
        if Keyword.get(opts, :underline), do: [:underline], else: []

    %__MODULE__{
      char: char,
      fg: normalize_color(fg),
      bg: normalize_color(bg),
      effects: Enum.uniq(effects)
    }
  end

  @doc """
  Creates an empty cell (space, no color, no effects).

  ## Examples

      iex> Cell.empty()
      %Cell{char: " ", fg: nil, bg: nil, effects: []}
  """
  @spec empty() :: t()
  def empty, do: %__MODULE__{}

  @doc """
  Compares two cells for visual equality.

  Two cells are equal if they would produce identical terminal output.
  Effects are compared as sets (order-independent).
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.char == b.char and
      a.fg == b.fg and
      a.bg == b.bg and
      MapSet.new(a.effects) == MapSet.new(b.effects)
  end

  @doc """
  Merges two cells, with the overlay cell taking precedence over the base.

  - If overlay has a non-space char, it replaces base.char
  - If overlay has a non-nil color, it replaces base color
  - Effects are merged (overlay first, unique)

  ## Examples

      iex> base = Cell.new("A", {255, 0, 0})
      iex> overlay = Cell.new("B", {0, 255, 0})
      iex> Cell.merge(base, overlay)
      %Cell{char: "B", fg: {0, 255, 0}, bg: nil, effects: []}
  """
  @spec merge(t(), t()) :: t()
  def merge(%__MODULE__{} = base, %__MODULE__{} = overlay) do
    %__MODULE__{
      char: if(overlay.char != " ", do: overlay.char, else: base.char),
      fg: overlay.fg || base.fg,
      bg: overlay.bg || base.bg,
      effects: (overlay.effects ++ base.effects) |> Enum.uniq()
    }
  end

  @doc """
  Applies an additional effect to a cell, returning a new cell.

  ## Examples

      iex> cell = Cell.new("A", {255, 0, 0})
      iex> Cell.apply_effect(cell, :bold)
      %Cell{char: "A", fg: {255, 0, 0}, bg: nil, effects: [:bold]}
  """
  @spec apply_effect(t(), effect()) :: t()
  def apply_effect(%__MODULE__{} = cell, effect) do
    %{cell | effects: Enum.uniq([effect | cell.effects])}
  end

  @doc """
  Returns the visual display width of the cell's character.

  ASCII characters have width 1. Wide characters (CJK, emoji) have width 2.
  Control characters have width 0.

  ## Examples

      iex> Cell.visual_width(Cell.new("A"))
      1

      iex> Cell.visual_width(Cell.new("中"))
      2
  """
  @spec visual_width(t()) :: 0 | 1 | 2
  def visual_width(%__MODULE__{char: char}), do: char_width(char)

  @doc """
  Converts a cell to its ANSI escape sequence representation.

  Produces true-color (24-bit) ANSI sequences for RGB colors.
  Always resets formatting after the character.

  ## Examples

      iex> Cell.to_ansi(Cell.new("X", {255, 0, 0}))
      "\e[38;2;255;0;0mX\e[0m"

      iex> Cell.to_ansi(Cell.empty())
      " "
  """
  @spec to_ansi(t()) :: iodata()
  def to_ansi(%__MODULE__{char: char, fg: nil, bg: nil, effects: []}) do
    char
  end

  def to_ansi(%__MODULE__{} = cell) do
    [build_ansi_prefix(cell), cell.char, IO.ANSI.reset()]
  end

  @doc """
  Returns the ANSI prefix for a cell without the character or reset.

  Enables run-length encoding in the renderer: consecutive cells with
  identical styling share a single prefix and reset.
  """
  @spec to_ansi_prefix(t()) :: iodata()
  def to_ansi_prefix(%__MODULE__{fg: nil, bg: nil, effects: []}), do: []

  def to_ansi_prefix(%__MODULE__{} = cell) do
    build_ansi_prefix(cell)
  end

  @spec normalize_color(color() | any()) :: color()
  defp normalize_color(nil), do: nil

  defp normalize_color({r, g, b})
       when is_integer(r) and is_integer(g) and is_integer(b) do
    {clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255)}
  end

  defp normalize_color(atom) when is_atom(atom), do: atom

  defp normalize_color(_), do: nil

  @spec clamp(integer(), integer(), integer()) :: integer()
  defp clamp(value, lo, hi), do: min(max(value, lo), hi)

  @spec build_ansi_prefix(t()) :: iodata()
  defp build_ansi_prefix(%__MODULE__{fg: fg, bg: bg, effects: effects}) do
    [
      if(fg, do: ansi_fg(fg), else: []),
      if(bg, do: ansi_bg(bg), else: []),
      ansi_effects(effects)
    ]
  end

  @spec ansi_fg({0..255, 0..255, 0..255}) :: String.t()
  defp ansi_fg({r, g, b}), do: "\e[38;2;#{r};#{g};#{b}m"

  defp ansi_fg(atom) when is_atom(atom) do
    case safe_pote_color(atom) do
      nil -> []
      {r, g, b} -> "\e[38;2;#{r};#{g};#{b}m"
    end
  end

  defp ansi_fg(_unknown), do: []

  @spec ansi_bg({0..255, 0..255, 0..255}) :: String.t()
  defp ansi_bg({r, g, b}), do: "\e[48;2;#{r};#{g};#{b}m"

  defp ansi_bg(atom) when is_atom(atom) do
    case safe_pote_color(atom) do
      nil -> []
      {r, g, b} -> "\e[48;2;#{r};#{g};#{b}m"
    end
  end

  defp ansi_bg(_unknown), do: []

  # Resolve a colour atom through the registered theme resolver stack.
  #
  # Previously this called `Pote.color/1` which only consulted Pote's
  # own hardcoded `@default_colors` map, completely bypassing any
  # registered theme resolver (e.g. the one registered by
  # `Alaja.Theme.register_with_pote/0`). This meant that when a user
  # configured an Alaja theme and passed `:primary` as a colour atom,
  # they would always see Pote's default `{161, 231, 250}` instead of
  # the active theme's value.
  #
  # `Pote.resolve_theme_color/1` walks the registered resolver stack
  # first and only falls back to `@default_colors` when no resolver
  # returns a match — so the active theme wins.
  @spec safe_pote_color(term()) :: {0..255, 0..255, 0..255} | nil
  defp safe_pote_color(term) do
    case Pote.resolve_theme_color(term) do
      {:ok, rgb} -> rgb
      :not_found -> nil
    end
  end

  @spec ansi_effects(effects()) :: iodata()
  defp ansi_effects([]), do: []
  defp ansi_effects(effects), do: Enum.map(effects, &effect_to_ansi/1)

  @spec effect_to_ansi(effect()) :: String.t()
  defp effect_to_ansi(:bold), do: IO.ANSI.bright()
  defp effect_to_ansi(:dim), do: IO.ANSI.faint()
  defp effect_to_ansi(:italic), do: IO.ANSI.italic()
  defp effect_to_ansi(:underline), do: IO.ANSI.underline()
  defp effect_to_ansi(:strikethrough), do: IO.ANSI.crossed_out()
  defp effect_to_ansi(:reverse), do: IO.ANSI.reverse()
  defp effect_to_ansi(:blink), do: IO.ANSI.blink_slow()
  defp effect_to_ansi(:hidden), do: IO.ANSI.conceal()

  @wide_char_ranges [
    0x1100..0x115F,
    0x2E80..0x2EFF,
    0x2F00..0x2FDF,
    0x2FF0..0x2FFF,
    0x3000..0x303F,
    0x3040..0x309F,
    0x30A0..0x30FF,
    0x3100..0x312F,
    0x3130..0x318F,
    0x3190..0x319F,
    0x31A0..0x31BF,
    0x31C0..0x31EF,
    0x31F0..0x31FF,
    0x3200..0x32FF,
    0x3300..0x33FF,
    0x3400..0x4DBF,
    0x4E00..0x9FFF,
    0xA000..0xA48F,
    0xA490..0xA4CF,
    0xA960..0xA97F,
    0xAC00..0xD7AF,
    0xF900..0xFAFF,
    0xFE10..0xFE1F,
    0xFE30..0xFE4F,
    0xFE50..0xFE6F,
    0xFF00..0xFF60,
    0xFFE0..0xFFE6,
    0x1B000..0x1B0FF,
    0x1F004..0x1F0CF,
    0x1F300..0x1F9FF,
    0x20000..0x2A6DF,
    0x2A700..0x2B73F,
    0x2B740..0x2B81F,
    0x2B820..0x2CEAF,
    0x2F800..0x2FA1F
  ]

  @spec char_width(String.t()) :: 0 | 1 | 2
  # ASCII byte: 0x00..0x7F (one column, control chars are 0 width).
  defp char_width(<<cp::utf8, _::binary>>) when cp <= 0x7F do
    if cp <= 0x1F, do: 0, else: 1
  end

  # Multi-byte UTF-8: first byte 0x80..0xFF — must decode the codepoint,
  # not just inspect the first byte, to detect wide characters.
  defp char_width(<<cp::utf8, _::binary>>) do
    if wide_char?(cp), do: 2, else: 1
  end

  defp char_width(_), do: 0

  # Dialyzer cannot infer the codepoint type from <<cp::utf8, _::binary>>
  # because the tail is _::binary (any size). The two-clause pattern is
  # correct at runtime; the type annotation just confuses the analyser.
  @dialyzer {:nowarn_function, char_width: 1}

  defp wide_char?(cp) do
    Enum.any?(@wide_char_ranges, fn range -> cp in range end)
  end
end
