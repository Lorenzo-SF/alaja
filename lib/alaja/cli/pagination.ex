defmodule Alaja.CLI.Pagination do
  @moduledoc """
  Interactive pagination utilities for CLI output.

  Provides functions for paginating long lists of items with keyboard navigation.
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
    div(total_items + page_size - 1, page_size)
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
  Handles navigation input and returns the next page number.
  Returns `:quit` to exit pagination.
  """
  @spec handle_nav(String.t(), non_neg_integer(), non_neg_integer()) :: non_neg_integer() | :quit
  def handle_nav(key, current_page, total_pages)

  def handle_nav("n", page, total_pages), do: min(page + 1, total_pages - 1)
  def handle_nav("p", page, _total_pages), do: max(page - 1, 0)
  def handle_nav("f", _page, _total_pages), do: 0
  def handle_nav("l", _page, total_pages), do: total_pages - 1
  def handle_nav("g", _page, _total_pages), do: :goto
  def handle_nav("q", _page, _total_pages), do: :quit
  def handle_nav("\e", _page, _total_pages), do: :quit
  def handle_nav(_key, page, _total_pages), do: page

  @doc """
  Reads a key from the user with a prompt.
  """
  @spec read_key(String.t()) :: String.t()
  def read_key(prompt \\ "Press key: ") do
    case IO.gets(prompt) do
      :eof -> " "
      "" -> " "
      input -> String.first(String.trim(input)) || " "
    end
  end

  @doc """
  Prompts for a page number and returns the 0-indexed page.
  Returns `:stay` if invalid input.
  """
  @spec goto_page(non_neg_integer()) :: non_neg_integer() | :stay
  def goto_page(total_pages) do
    IO.write("Go to page (1-#{total_pages}): ")
    input = IO.gets("") |> String.trim()

    case Integer.parse(input) do
      {n, _} when n >= 1 and n <= total_pages ->
        n - 1

      _ ->
        :stay
    end
  end

  @doc """
  Maps a key to its navigation action.
  """
  @spec map_key(String.t()) :: atom()
  def map_key(key) do
    Map.get(@nav_keys, key, :unknown)
  end
end
