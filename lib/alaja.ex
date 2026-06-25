defmodule Alaja do
  @moduledoc """
  Public facade for the Alaja terminal rendering framework.

  Provides a simplified API for the most common operations: printing
  styled messages (`print_success`, `print_error`, `print_warning`,
  `print_info`), creating buffers and cells, converting colour formats,
  and rendering tables.

  For advanced usage see the sub-modules directly:
  `Alaja.Printer`, `Alaja.Components`, and `Alaja.Buffer`.
  """

  alias Alaja.{Buffer, Cell, Printer}
  alias Pote.Conversions

  @doc """
  Creates an empty cell (space, no colour, no effects).

  Returns a `%Cell{}` struct filled with defaults.
  """
  @spec empty() :: Cell.t()
  def empty, do: Cell.new()

  @doc """
  Creates a new buffer with the given dimensions.

  Returns a `%Buffer{}` with `width * height` empty cells stored in a
  flat tuple for O(1) access.
  """
  @spec new_buffer(non_neg_integer(), non_neg_integer()) :: Buffer.t()
  def new_buffer(width, height), do: Buffer.new(width, height)

  @doc """
  Converts an RGB tuple to uppercase hex string.

  ## Examples

      iex> Alaja.rgb_to_hex({255, 180, 0})
      "#FFB400"
  """
  @spec rgb_to_hex({byte(), byte(), byte()}) :: String.t()
  def rgb_to_hex({r, g, b}) do
    Conversions.rgb_to_hex({r, g, b})
  end

  @doc "Prints a success message (icon: ✓)."
  @spec print_success(String.t()) :: :ok
  defdelegate print_success(msg), to: Printer

  @doc "Prints an error message (icon: ✗)."
  @spec print_error(String.t()) :: :ok
  defdelegate print_error(msg), to: Printer

  @doc "Prints a warning message (icon: ⚠)."
  @spec print_warning(String.t()) :: :ok
  defdelegate print_warning(msg), to: Printer

  @doc "Prints an informational message (icon: ℹ)."
  @spec print_info(String.t()) :: :ok
  defdelegate print_info(msg), to: Printer

  @doc """
  Prints a table to stdout.

  Delegates to `Alaja.Components.Table.print/2`. Accepts a keyword list
  or a list of lists where the first row is treated as headers.
  """
  @spec print(keyword() | list()) :: :ok
  defdelegate print(opts), to: Alaja.Components.Table

  @doc """
  Writes an `iodata` payload to stdout **without any transformation**.

  Use this when you need to emit raw ANSI escapes (or any pre-formatted
  text) that should pass through untouched by Alaja's printers.

  ## Example

      Alaja.print_raw("\\e[31mError\\e[0m\\n")
  """
  @spec print_raw(iodata()) :: :ok
  def print_raw(iodata), do: IO.write(iodata)

  @doc """
  Writes an `iodata` payload to a specific device (default `:stdio`).

  ## Options

    * `:device` — `:stdio | {:fd, posix} | pid()`. Defaults to `:stdio`.

  Useful for writing to alternative file descriptors or to a process
  socket in interactive components.
  """
  @spec print_raw(iodata(), keyword()) :: :ok
  def print_raw(iodata, opts) do
    opts = Keyword.put_new(opts, :device, :stdio)
    IO.write(Keyword.fetch!(opts, :device), iodata)
  end

  @doc """
  Unified entry point for running an Alaja-based CLI.

  The default `cli_module` is `Alaja.CLI` (the self-hosted demo CLI shipped
  with the framework). Pass any module built with
  `use Alaja.CLI.Definition, otp_app: :my_app, halt_on_error: true` to run your own (escript-style aborts the BEAM on error). Set `halt_on_error: false` if you want main/1 to return `{:error, reason}` instead.

  Both escript entry points and library callers should go through this
  function rather than calling `cli_module.main/1` directly so the
  public facade has a single documented entry point.

  ## Examples

      # Library caller
      Alaja.run(System.argv())

      # Custom CLI
      Alaja.run(System.argv(), MyApp.CLI)

      # escript main_module
      defmodule MyApp.CLIEntry do
        def main(argv), do: Alaja.run(argv, MyApp.CLI)
      end
  """
  @spec run([String.t()], module()) :: any()
  def run(argv, cli_module \\ Alaja.CLI) when is_list(argv) and is_atom(cli_module) do
    cli_module.main(argv)
  end
end
