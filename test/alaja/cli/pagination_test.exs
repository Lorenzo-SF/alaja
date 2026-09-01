defmodule Alaja.CLI.PaginationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Alaja.CLI.Pagination

  describe "total_pages/2" do
    test "calculates pages for exact division" do
      assert Pagination.total_pages(100, 10) == 10
    end

    test "rounds up for remainder" do
      assert Pagination.total_pages(101, 10) == 11
    end

    test "handles zero items" do
      assert Pagination.total_pages(0, 10) == 1
    end

    test "handles items less than page size" do
      assert Pagination.total_pages(5, 10) == 1
    end
  end

  describe "clamp_page/3" do
    test "clamps a page beyond the data range to the first page" do
      assert Pagination.clamp_page(3, 45, 40) == 0
    end

    test "keeps a valid page" do
      assert Pagination.clamp_page(1, 10, 40) == 1
    end

    test "clamps negative pages to zero" do
      assert Pagination.clamp_page(-2, 10, 40) == 0
    end

    test "empty dataset always shows the first page" do
      assert Pagination.clamp_page(5, 10, 0) == 0
    end
  end

  describe "parse_escape/1" do
    test "parses arrow sequences" do
      assert Pagination.parse_escape("\e[C") == :right
      assert Pagination.parse_escape("\e[D") == :left
      assert Pagination.parse_escape("\e[A") == :up
      assert Pagination.parse_escape("\e[B") == :down
    end

    test "falls back to :esc" do
      assert Pagination.parse_escape("\e") == :esc
      assert Pagination.parse_escape("\e[Z") == :esc
    end
  end

  describe "goto_page/2" do
    test "returns the 0-based page for valid input" do
      assert capture_io("3\n", fn ->
               assert Pagination.goto_page(10, 2) == 2
             end) =~ "Go to page"
    end

    test "keeps the current page on invalid input (no crash)" do
      assert capture_io("abc\n", fn ->
               assert Pagination.goto_page(10, 2) == 2
             end) =~ "Go to page"
    end

    test "keeps the current page on out-of-range input" do
      assert capture_io("99\n", fn ->
               assert Pagination.goto_page(10, 2) == 2
             end) =~ "Go to page"
    end
  end

  describe "page_items/3" do
    test "returns correct slice for first page" do
      items = 1..100 |> Enum.to_list()
      assert Pagination.page_items(items, 0, 10) == 1..10 |> Enum.to_list()
    end

    test "returns correct slice for middle page" do
      items = 1..100 |> Enum.to_list()
      assert Pagination.page_items(items, 5, 10) == 51..60 |> Enum.to_list()
    end

    test "returns correct slice for last page" do
      items = 1..100 |> Enum.to_list()
      assert Pagination.page_items(items, 9, 10) == 91..100 |> Enum.to_list()
    end

    test "handles partial last page" do
      items = 1..105 |> Enum.to_list()
      assert Pagination.page_items(items, 10, 10) == 101..105 |> Enum.to_list()
    end

    test "handles empty list" do
      assert Pagination.page_items([], 0, 10) == []
    end
  end

  describe "handle_nav/3" do
    test "n goes to next page" do
      assert Pagination.handle_nav("n", 5, 10) == 6
    end

    test "n stays at last page" do
      assert Pagination.handle_nav("n", 9, 10) == 9
    end

    test "p goes to previous page" do
      assert Pagination.handle_nav("p", 5, 10) == 4
    end

    test "p stays at first page" do
      assert Pagination.handle_nav("p", 0, 10) == 0
    end

    test "f goes to first page" do
      assert Pagination.handle_nav("f", 5, 10) == 0
    end

    test "l goes to last page" do
      assert Pagination.handle_nav("l", 5, 10) == 9
    end

    test "arrow keys navigate" do
      assert Pagination.handle_nav(:right, 5, 10) == 6
      assert Pagination.handle_nav(:right, 9, 10) == 9
      assert Pagination.handle_nav(:left, 5, 10) == 4
      assert Pagination.handle_nav(:left, 0, 10) == 0
    end

    test "g returns :goto" do
      assert Pagination.handle_nav("g", 5, 10) == :goto
    end

    test "q returns :quit" do
      assert Pagination.handle_nav("q", 5, 10) == :quit
    end

    test "escape returns :quit" do
      assert Pagination.handle_nav("\e", 5, 10) == :quit
      assert Pagination.handle_nav(:esc, 5, 10) == :quit
    end

    test "unknown key stays on same page" do
      assert Pagination.handle_nav("x", 5, 10) == 5
    end
  end

  describe "nav_help/2" do
    test "returns formatted string with page info" do
      help = Pagination.nav_help(0, 10)
      assert help =~ "Page 1/10"
      assert help =~ "n=next"
      assert help =~ "p=prev"
    end
  end

  describe "map_key/1" do
    test "maps navigation keys correctly" do
      assert Pagination.map_key("n") == :next
      assert Pagination.map_key("p") == :prev
      assert Pagination.map_key("f") == :first
      assert Pagination.map_key("l") == :last
      assert Pagination.map_key("g") == :goto
      assert Pagination.map_key("q") == :quit
    end

    test "returns :unknown for non-navigation keys" do
      assert Pagination.map_key("x") == :unknown
    end
  end
end
