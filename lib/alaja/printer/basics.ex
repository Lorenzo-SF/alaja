defmodule Alaja.Printer.Basics do
  @moduledoc """
  Pre-styled message printing with severity gliphicons and theme colours.

  Provides 12 severity-level functions — info, success, error, warning,
  alert, critical, debug, notice, emergency, happy, sad. Each prefixes
  the message with an ASCII gliphicons in brackets and applies colour
  styling resolved through Pote's theme system.

  ## Gliphicons

  Each level uses a simple ASCII gliphicons so the icon and the message
  can share a single chunk with the theme colour applied to both:

      [✓] Deploy completado
      [✗] Build fallido
      [!] Cuidado con X
      [i] Información útil
      [?] Detalle de bajo nivel
      [i] Aviso importante
      [!] Cuidado (inverted warning background)
      [!!] Crítico (inverted error background)
      [SOS] Emergencia (inverted error background, blinking)
      [+] Todo va bien
      [-] Triste

  ## Colour mapping

  Every function uses the theme colour with the matching name:

      print_info      -> theme:info
      print_success   -> theme:success
      print_error     -> theme:error (bold)
      print_warning   -> theme:warning
      print_debug     -> theme:debug
      print_notice    -> theme:info
      print_happy     -> theme:happy
      print_sad       -> theme:sad

  And the inverted-background variants print the gliphicons + message
  in `theme:background` on a `theme:warning` (alert) or `theme:error`
  (critical, emergency) background.
  """

  alias Alaja.Printer
  alias Alaja.Structures.{ChunkText, MessageInfo}

  @doc """
  Prints an informational message.

  Gliphicons: `[i]` — colour: theme:info.
  """
  @spec print_info(String.t(), keyword()) :: :ok | String.t()
  def print_info(text, opts \\ []) do
    emit("[i]", text, :info, opts)
  end

  @doc """
  Prints a success message.

  Gliphicons: `[✓]` — colour: theme:success.
  """
  @spec print_success(String.t(), keyword()) :: :ok | String.t()
  def print_success(text, opts \\ []) do
    emit("[✓]", text, :success, opts)
  end

  @doc """
  Prints an error message.

  Gliphicons: `[✗]` — colour: theme:error, bold.
  """
  @spec print_error(String.t(), keyword()) :: :ok | String.t()
  def print_error(text, opts \\ []) do
    emit("[✗]", text, :error, opts, effects: [:bold])
  end

  @doc """
  Prints a warning message.

  Gliphicons: `[!]` — colour: theme:warning.
  """
  @spec print_warning(String.t(), keyword()) :: :ok | String.t()
  def print_warning(text, opts \\ []) do
    emit("[!]", text, :warning, opts)
  end

  @doc """
  Prints an alert message (inverted warning).

  Gliphicons: `[!]` — text in theme:background on theme:warning
  background, bold.
  """
  @spec print_alert(String.t(), keyword()) :: :ok | String.t()
  def print_alert(text, opts \\ []) do
    emit_inverted("[!]", text, :warning, opts, effects: [:bold])
  end

  @doc """
  Prints a critical message (inverted error).

  Gliphicons: `[!!]` — text in theme:background on theme:error
  background, bold.
  """
  @spec print_critical(String.t(), keyword()) :: :ok | String.t()
  def print_critical(text, opts \\ []) do
    emit_inverted("[!!]", text, :error, opts, effects: [:bold])
  end

  @doc """
  Prints a debug message.

  Gliphicons: `[?]` — colour: theme:debug.
  """
  @spec print_debug(String.t(), keyword()) :: :ok | String.t()
  def print_debug(text, opts \\ []) do
    emit("[?]", text, :debug, opts)
  end

  @doc """
  Prints a happy/positive message.

  Gliphicons: `[+]` — colour: theme:happy.
  """
  @spec print_happy(String.t(), keyword()) :: :ok | String.t()
  def print_happy(text, opts \\ []) do
    emit("[+]", text, :happy, opts)
  end

  @doc """
  Prints a sad/negative message.

  Gliphicons: `[-]` — colour: theme:sad.
  """
  @spec print_sad(String.t(), keyword()) :: :ok | String.t()
  def print_sad(text, opts \\ []) do
    emit("[-]", text, :sad, opts)
  end

  @doc """
  Prints a notice message.

  Gliphicons: `[i]` — colour: theme:info.
  """
  @spec print_notice(String.t(), keyword()) :: :ok | String.t()
  def print_notice(text, opts \\ []) do
    emit("[i]", text, :info, opts)
  end

  @doc """
  Prints an emergency message.

  Gliphicons: `[SOS]` — text in theme:background on theme:error
  background, bold and blinking.
  """
  @spec print_emergency(String.t(), keyword()) :: :ok | String.t()
  def print_emergency(text, opts \\ []) do
    emit_inverted("[SOS]", text, :error, opts, effects: [:bold, :blink])
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Standard flat message: gliphicons in its own chunk (with the theme
  # colour), then the message in another chunk with the same colour.
  defp emit(gliph, text, color, opts, chunk_opts \\ []) do
    chunks = [
      ChunkText.new(" " <> gliph <> " ",
        color: color,
        effects: Keyword.get(chunk_opts, :effects, [])
      ),
      ChunkText.new(text, color: color, effects: Keyword.get(chunk_opts, :text_effects, []))
    ]

    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end

  # Inverted-background message: gliphicons + message share the
  # `theme:background` foreground colour over a `bg_color` background.
  # Used for alert / critical / emergency.
  defp emit_inverted(gliph, text, bg_color, opts, effects) do
    chunks = [
      ChunkText.new(" " <> gliph <> " ",
        color: :background,
        bg_color: bg_color,
        effects: effects
      ),
      ChunkText.new(" " <> text, color: :background, bg_color: bg_color, effects: effects)
    ]

    Printer.print(MessageInfo.new(chunks, Keyword.put_new(opts, :add_line, :after)), opts)
  end
end
