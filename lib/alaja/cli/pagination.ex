defmodule Alaja.CLI.Pagination do
  @moduledoc """
  Interactive pagination utilities for CLI output.

  Provides pure navigation helpers plus a raw-mode key reader (no Enter
  needed) used by the paginated table and the tabbed help renderer.

  ## Key handling

  `read_key/0` puts the terminal in raw mode and returns a normalized
  key:

    * `:right`, `:left`, `:up`, `:down` — arrow keys
    * `:esc` — Escape
    * `:enter` — Enter/Return
    * `:backspace` — Backspace/DEL
    * a single-character string — printable alphanumeric characters
  """

  @nav_keys %{
    "n" => :next,
    "p" => :prev,
    "f" => :first,
    "l" => :last,
    "g" => :goto,
    "q" => :quit
  }

  @doc """
  Returns the navigation help message.
  """
  @spec nav_help(non_neg_integer(), non_neg_integer()) :: String.t()
  def nav_help(current_page, total_pages) do
    "Page #{current_page + 1}/#{total_pages} | n=next  p=prev  f=first  l=last  g=goto  q=quit"
  end

  @doc """
  Calculates the number of pages needed for a given total items and page size.
  """
  @spec total_pages(non_neg_integer(), pos_integer()) :: non_neg_integer()
  def total_pages(total_items, page_size) when total_items >= 0 and page_size > 0 do
    max(div(total_items + page_size - 1, page_size), 1)
  end

  @doc """
  Gets the slice of items for a given page.
  """
  @spec page_items([any()], non_neg_integer(), pos_integer()) :: [any()]
  def page_items(items, page, page_size) do
    start_idx = page * page_size
    Enum.slice(items, start_idx, page_size)
  end

  @doc """
  Clamps a requested page so it can never fall outside the valid range.

  Returns `0` when the requested page does not exist (the first page is
  always shown instead, even for an empty dataset).
  """
  @spec clamp_page(non_neg_integer(), pos_integer(), non_neg_integer()) :: non_neg_integer()
  def clamp_page(page, page_size, total_rows) when total_rows > 0 do
    max_page = max(div(total_rows - 1, page_size), 0)
    min(max(page, 0), max_page)
  end

  def clamp_page(_page, _page_size, _total_rows), do: 0

  @doc """
  Handles navigation input and returns the next page number.

  Returns `:quit` to exit pagination and `:goto` when the user asked to
  jump to a page (the caller prompts for the number).
  """
  @spec handle_nav(String.t() | atom(), non_neg_integer(), non_neg_integer()) ::
          non_neg_integer() | :quit | :goto
  def handle_nav(key, page, total_pages)

  def handle_nav(:right, page, total_pages), do: min(page + 1, max(total_pages - 1, 0))
  def handle_nav(:left, page, _total_pages), do: max(page - 1, 0)
  def handle_nav("n", page, total_pages), do: min(page + 1, max(total_pages - 1, 0))
  def handle_nav("p", page, _total_pages), do: max(page - 1, 0)
  def handle_nav("f", _page, _total_pages), do: 0
  def handle_nav("l", _page, total_pages), do: max(total_pages - 1, 0)
  def handle_nav("g", _page, _total_pages), do: :goto
  def handle_nav("q", _page, _total_pages), do: :quit
  def handle_nav(:esc, _page, _total_pages), do: :quit
  def handle_nav("\e", _page, _total_pages), do: :quit
  def handle_nav(_key, page, _total_pages), do: page

  @doc """
  Runs `fun` with the terminal in raw mode (no echo, no canonical line
  editing) and restores the previous terminal state afterwards.

  No-op when stdin is not a terminal.
  """
  @spec raw_mode(fun()) :: term()
  def raw_mode(fun) do
    case tty_device() do
      nil ->
        fun.()

      dev ->
        saved = save_terminal(dev)

        try do
          System.cmd("sh", ["-c", "stty raw -echo < '#{dev}'"])
          fun.()
        after
          restore_terminal(dev, saved)
        end
    end
  end

  @doc """
  Reads a single key from stdin in raw mode.

  See the module documentation for the returned values.
  """
  @spec read_key() :: String.t() | atom()
  def read_key do
    raw_mode(fn ->
      case IO.binread(:stdio, 1) do
        :eof -> :esc
        nil -> :esc
        byte when byte in ["\e"] -> read_escape_sequence()
        "\r" -> :enter
        "\n" -> :enter
        byte when byte in ["\b", "\x7f"] -> :backspace
        byte when byte in ["\t"] -> :tab
        char -> char
      end
    end)
  end

  @doc """
  Parses an Escape-prefixed input chunk into a normalized key.

  Pure function, exposed for tests: `"\e[C"` → `:right`, `"\e[D"` →
  `:left`, `"\e"` alone → `:esc`.
  """
  @spec parse_escape(String.t()) :: atom()
  def parse_escape("\e[C"), do: :right
  def parse_escape("\e[D"), do: :left
  def parse_escape("\e[A"), do: :up
  def parse_escape("\e[B"), do: :down
  def parse_escape("\e[3~"), do: :delete
  def parse_escape(_), do: :esc

  @doc """
  Prompts for a page number and returns the 0-indexed page.

  On invalid input the current page is returned unchanged (never
  crashes the caller).
  """
  @spec goto_page(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def goto_page(total_pages, current_page) do
    IO.write("Go to page (1-#{total_pages}): ")

    input =
      case IO.gets("") do
        :eof -> ""
        result when is_binary(result) -> String.trim(result)
        _ -> ""
      end

    case Integer.parse(input) do
      {n, _} when n >= 1 and n <= total_pages -> n - 1
      _ -> current_page
    end
  end

  @doc """
  Maps a key to its navigation action.
  """
  @spec map_key(String.t()) :: atom()
  def map_key(key) do
    Map.get(@nav_keys, key, :unknown)
  end

  @doc """
  Whether stdin is an interactive terminal.

  Uses `/dev/tty` (POSIX) rather than `IO.ANSI.enabled?/0`, because the
  latter reports true under `ExUnit.CaptureIO` and other non-TTY
  redirections, which would make interactive loops block forever.

  The Erlang VM does not report its stdin as a TTY when launched under a
  pseudo-terminal (e.g. `script` or `pty.fork`), but `/dev/tty` is still
  openable — so we test that instead of `isatty(0)`. Under `mix test`
  the check is skipped entirely: the suite is never interactive.
  """
  @spec tty?() :: boolean()
  def tty? do
    if Code.ensure_loaded?(ExUnit) and
         function_exported?(ExUnit, :fetch_test_supervisor, 0) and
         match?({:ok, _}, apply(ExUnit, :fetch_test_supervisor, [])) do
      false
    else
      tty_device() != nil
    end
  rescue
    _ -> false
  end

  @doc false
  @spec tty_device() :: String.t() | nil
  def tty_device do
    cmd = "ps -p " <> to_string(:os.getpid()) <> " -o tty="

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {out, 0} ->
        case String.trim(out) do
          "" -> nil
          "??" -> nil
          "?" -> nil
          tty -> "/dev/" <> tty
        end

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp read_escape_sequence do
    case IO.binread(:stdio, 2) do
      :eof -> :esc
      nil -> :esc
      chunk -> parse_escape("\e" <> chunk)
    end
  end

  defp save_terminal(dev) do
    case System.cmd("sh", ["-c", "stty -g < '#{dev}'"]) do
      {out, 0} -> String.trim(out)
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp restore_terminal(_dev, nil), do: :ok

  defp restore_terminal(dev, saved) do
    System.cmd("sh", ["-c", "stty '#{saved}' < '#{dev}'"])
    :ok
  rescue
    _ -> :ok
  end
end
