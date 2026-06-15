defmodule Alaja.Terminal do
  @moduledoc """
  Terminal size detection utilities.

  Wraps `:io.columns/0` and `:io.rows/0` with sensible fallbacks for
  non-TTY environments.
  """

  @doc """
  Returns the current terminal dimensions as `{columns, rows}`.

  Falls back to `{80, 24}` if the terminal size cannot be detected
  (e.g., in non-TTY environments, CI, or when stdout is redirected).
  """
  @spec size() :: {pos_integer(), pos_integer()}
  def size do
    {columns(), rows()}
  end

  @doc """
  Returns the terminal width in columns.
  """
  @spec width() :: pos_integer()
  def width, do: columns()

  @doc """
  Returns the terminal height in rows.
  """
  @spec height() :: pos_integer()
  def height, do: rows()

  defp columns do
    case :io.columns() do
      {:ok, n} when n > 0 -> n
      _ -> 80
    end
  end

  defp rows do
    case :io.rows() do
      {:ok, n} when n > 0 -> n
      _ -> 24
    end
  end
end
