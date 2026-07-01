defmodule Alaja.Components.TableTest do
  use ExUnit.Case

  alias Alaja.{Buffer, Components.Table}

  describe "render/2" do
    test "renders table with headers and rows as Buffer.t()" do
      data = [
        ["ID", "Name", "Status"],
        ["1", "Alice", "Active"],
        ["2", "Bob", "Inactive"]
      ]

      assert %Buffer{} = output = Table.render(data)
      str = Buffer.to_iodata(output) |> IO.iodata_to_binary()
      assert str =~ "ID"
      assert str =~ "Alice"
      assert str =~ "Bob"
    end

    test "renders with keyword options as Buffer.t()" do
      assert %Buffer{} =
               output =
               Table.render(
                 headers: ["Col1", "Col2"],
                 rows: [["A", "B"]],
                 headers_color: :cyan,
                 table_border: :rounded
               )

      str = Buffer.to_iodata(output) |> IO.iodata_to_binary()
      assert str =~ "Col1"
      assert str =~ "A"
    end

    test "renders with empty rows as Buffer.t()" do
      assert %Buffer{} =
               output =
               Table.render(
                 headers: ["Col1", "Col2"],
                 rows: []
               )

      str = Buffer.to_iodata(output) |> IO.iodata_to_binary()
      assert str =~ "Col1"
      assert str =~ "Col2"
    end

    test "renders with different border styles" do
      for border <- [:normal, :rounded, :double, :none] do
        assert %Buffer{} =
                 output =
                 Table.render(
                   headers: ["A"],
                   rows: [["B"]],
                   table_border: border
                 )

        str = Buffer.to_iodata(output) |> IO.iodata_to_binary()
        assert str =~ "A"
        assert str =~ "B"
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
