defmodule Alaja.CLI.PaginationTest do
  use ExUnit.Case, async: true

  alias Alaja.CLI.Pagination

  describe "total_pages/2" do
    test "calculates pages for exact division" do
      assert Pagination.total_pages(100, 10) == 10
    end

    test "rounds up for remainder" do
      assert Pagination.total_pages(101, 10) == 11
    end

    test "handles zero items" do
      assert Pagination.total_pages(0, 10) == 0
    end

    test "handles items less than page size" do
      assert Pagination.total_pages(5, 10) == 1
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

    test "g returns :goto" do
      assert Pagination.handle_nav("g", 5, 10) == :goto
    end

    test "q returns :quit" do
      assert Pagination.handle_nav("q", 5, 10) == :quit
    end

    test "escape returns :quit" do
      assert Pagination.handle_nav("\e", 5, 10) == :quit
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
