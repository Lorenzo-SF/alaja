defmodule Alaja.Components.TablePaginationTest do
  @moduledoc """
  Tests for the paginated table mode: the pure paginator state machine
  (`apply_key/2`), the page builder (`build_page/7`, `row_matches?/2`)
  and the `:data_fun` contract with clamping.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Alaja.Components.Table
  alias Alaja.Components.Table.Builder
  alias Alaja.Components.Table.Page

  @headers ["name", "status"]

  defp rows(n) do
    Enum.map(1..n, fn i -> ["item #{i}", "ok"] end)
  end

  describe "apply_key/2" do
    setup do
      {:ok, state: %{page: 2, search: "api"}}
    end

    test "right arrow advances one page", %{state: state} do
      assert Builder.apply_key(:right, state) == %{state | page: 3}
    end

    test "left arrow goes back, never below zero", %{state: state} do
      assert Builder.apply_key(:left, state) == %{state | page: 1}
      assert Builder.apply_key(:left, %{page: 0, search: ""}) == %{page: 0, search: ""}
    end

    test "esc and q quit", %{state: state} do
      assert Builder.apply_key(:esc, state) == :quit
      assert Builder.apply_key("q", state) == :quit
    end

    test "backspace removes the last search character" do
      assert Builder.apply_key(:backspace, %{page: 1, search: "api"}) ==
               %{page: 1, search: "ap"}

      assert Builder.apply_key(:backspace, %{page: 1, search: ""}) ==
               %{page: 1, search: ""}
    end

    test "alphanumeric characters append to the search and reset the page" do
      assert Builder.apply_key("a", %{page: 3, search: "ap"}) == %{page: 0, search: "apa"}
    end

    test "non-alphanumeric characters are ignored" do
      assert Builder.apply_key(" ", %{page: 3, search: "ap"}) == %{page: 3, search: "ap"}
      assert Builder.apply_key("-", %{page: 3, search: "ap"}) == %{page: 3, search: "ap"}
    end

    test "enter keeps the state" do
      assert Builder.apply_key(:enter, %{page: 3, search: "ap"}) == %{page: 3, search: "ap"}
    end
  end

  describe "row_matches?/2" do
    test "matches case-insensitively over any cell" do
      assert Builder.row_matches?(["API Gateway", "ok"], "api")
      assert Builder.row_matches?(["API Gateway", "ok"], "GATEWAY")
      refute Builder.row_matches?(["API Gateway", "ok"], "nope")
    end

    test "handles non-string cells without crashing" do
      refute Builder.row_matches?([123, nil], "abc")
    end
  end

  describe "build_page/7 with a plain list" do
    test "slices the requested page" do
      page = Builder.build_page(@headers, rows(25), 10, nil, 1, "")

      assert %Page{page: 1, total_pages: 3, total_rows: 25} = page
      assert Enum.map(page.rows, &hd/1) == ["item 11", "item 12", "item 13", "item 14", "item 15", "item 16", "item 17", "item 18", "item 19", "item 20"]
    end

    test "clamps an impossible page to the first page with that page size" do
      page = Builder.build_page(@headers, rows(40), 45, nil, 3, "")

      assert page.page == 0
      assert page.total_pages == 1
      assert length(page.rows) == 40
    end

    test "clamps an impossible page to the last valid page" do
      page = Builder.build_page(@headers, rows(25), 10, nil, 9, "")

      assert page.page == 2
      assert length(page.rows) == 5
    end

    test "empty data renders page 0 with one empty page" do
      page = Builder.build_page(@headers, [], 10, nil, 3, "")

      assert page.page == 0
      assert page.total_pages == 1
      assert page.total_rows == 0
      assert page.rows == []
    end

    test "search filters rows with a like match" do
      page = Builder.build_page(@headers, rows(25), 10, nil, 0, "item 1")

      assert page.total_rows == 11
      assert Enum.map(page.rows, &hd/1) ==
               ["item 1", "item 10", "item 11", "item 12", "item 13", "item 14", "item 15", "item 16", "item 17", "item 18"]
    end

    test "search resets an out-of-range page" do
      page = Builder.build_page(@headers, rows(25), 10, nil, 5, "zzz")

      assert page.page == 0
      assert page.total_rows == 0
    end
  end

  describe "build_page/7 with :data_fun" do
    test "receives the request contract and returns the page" do
      parent = self()

      fun = fn req ->
        send(parent, {:called, req})
        %Page{headers: @headers, rows: [["a", "b"]], page: 0, total_pages: 4, total_rows: 40}
      end

      page = Builder.build_page([], [], 10, fun, 2, "api")

      assert page.rows == [["a", "b"]]
      assert_received {:called, %{page_size: 10, page: 2, search: "api"}}
    end

    test "retries with the first page when the result is impossible" do
      parent = self()

      fun = fn
        %{page: 3} ->
          send(parent, {:called, 3})
          %Page{headers: @headers, rows: [], page: 3, total_pages: 1, total_rows: 40}

        %{page: 0} ->
          send(parent, {:called, 0})
          %Page{headers: @headers, rows: rows(40), page: 0, total_pages: 1, total_rows: 40}
      end

      page = Builder.build_page([], [], 45, fun, 3, "")

      assert page.page == 0
      assert page.total_rows == 40
      assert_received {:called, 3}
      assert_received {:called, 0}
    end

    test "raises when the function does not return a Page struct" do
      assert_raise ArgumentError, ~r/must return an Alaja.Components.Table.Page/, fn ->
        Builder.build_page([], [], 10, fn _ -> :nope end, 0, "")
      end
    end
  end

  describe "Table.print/2 with pagination options" do
    test "raises when :data_fun is set without :page_size" do
      assert_raise ArgumentError, ~r/requires a positive :page_size/, fn ->
        Table.print(headers: @headers, rows: [], data_fun: fn _ -> %Page{} end)
      end
    end

    test "renders a single page without pagination when rows fit" do
      output =
        capture_io(fn ->
          Table.print(headers: @headers, rows: rows(3), page_size: 10)
        end)

      assert output =~ "item 1"
      refute output =~ "Page "
    end
  end
end
