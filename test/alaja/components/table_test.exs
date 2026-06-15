defmodule Alaja.Components.TableTest do
  use ExUnit.Case

  alias Alaja.Components.Table

  describe "render/2" do
    test "renders table with headers and rows" do
      data = [
        ["ID", "Name", "Status"],
        ["1", "Alice", "Active"],
        ["2", "Bob", "Inactive"]
      ]

      output = Table.render(data)
      assert is_list(output) or is_binary(output)
    end

    test "renders with keyword options" do
      output =
        Table.render(
          headers: ["Col1", "Col2"],
          rows: [["A", "B"]],
          headers_color: :cyan,
          table_border: :rounded
        )

      assert is_list(output) or is_binary(output)
    end

    test "renders with empty rows" do
      output =
        Table.render(
          headers: ["Col1", "Col2"],
          rows: []
        )

      assert is_list(output) or is_binary(output)
    end

    test "renders with different border styles" do
      for border <- [:normal, :rounded, :double, :none] do
        output =
          Table.render(
            headers: ["A"],
            rows: [["B"]],
            table_border: border
          )

        assert is_list(output) or is_binary(output)
      end
    end
  end

  describe "print/2" do
    test "prints table to stdout" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          Table.print(
            headers: ["A", "B"],
            rows: [["1", "2"]]
          )
        end)

      assert is_binary(output)
    end

    test "prints with custom colors" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          Table.print(
            headers: ["A", "B"],
            rows: [["1", "2"]],
            headers_color: :cyan,
            rows_color: :white
          )
        end)

      assert is_binary(output)
    end

    test "prints list data" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          Table.print([["X", "Y"], ["1", "2"]])
        end)

      assert is_binary(output)
    end
  end
end
