defmodule Alaja.Components.ComponentsTest do
  use ExUnit.Case

  alias Alaja.Components.{Bar, Box, Breadcrumbs, Header, Json, Separator}

  describe "Bar component" do
    test "render/3 returns iodata" do
      result = Bar.render(50, 100, label: "CPU", width: 20)
      assert is_list(result)
      str = IO.iodata_to_binary(result)
      assert String.contains?(str, "CPU")
      assert String.contains?(str, "50%")
    end
  end

  describe "Box component" do
    test "render/2 returns iodata" do
      result = Box.render("Hello World", title: "Test Box", border: :rounded)
      assert is_list(result)
      str = IO.iodata_to_binary(result)
      assert String.contains?(str, "Hello World")
      assert String.contains?(str, "Test Box")
      assert String.contains?(str, "╭")
    end

    test "render/2 handles lists of strings" do
      result = Box.render(["Line 1", "Line 2"], title: "Test Box", padding: 2)
      str = IO.iodata_to_binary(result)
      assert String.contains?(str, "Line 1")
      assert String.contains?(str, "Line 2")

      # Each content line must be on its own physical terminal line
      lines = String.split(str, "\n")
      content_line_1 = Enum.find(lines, &String.contains?(&1, "Line 1"))
      content_line_2 = Enum.find(lines, &String.contains?(&1, "Line 2"))
      assert content_line_1
      assert content_line_2
      refute String.contains?(content_line_1, "Line 2")
      refute String.contains?(content_line_2, "Line 1")
    end

    test "render/2 handles string with embedded newlines" do
      result = Box.render("Line A\nLine B", border: :rounded)
      str = IO.iodata_to_binary(result)

      lines = String.split(str, "\n")
      content_line_a = Enum.find(lines, &String.contains?(&1, "Line A"))
      content_line_b = Enum.find(lines, &String.contains?(&1, "Line B"))
      assert content_line_a
      assert content_line_b
      refute String.contains?(content_line_a, "Line B")
      refute String.contains?(content_line_b, "Line A")
    end
  end

  describe "Breadcrumbs component" do
    test "render/2 returns iodata" do
      result = Breadcrumbs.render(["Home", "Section", "Page"], separator: ">")
      assert is_list(result)
      str = IO.iodata_to_binary(result)
      assert String.contains?(str, "Home")
      assert String.contains?(str, "Section")
      assert String.contains?(str, "Page")
      assert String.contains?(str, ">")
    end

    test "render/2 handles empty list" do
      assert Breadcrumbs.render([], []) == []
    end
  end

  describe "Header component" do
    test "render/2 returns iodata for all sizes" do
      for size <- [:small, :medium, :large] do
        result = Header.render("Main Title", subtitle: "version 1.0", size: size)
        assert is_list(result)
        str = IO.iodata_to_binary(result)
        assert String.contains?(str, "Main Title")
        assert String.contains?(str, "version 1.0")
      end
    end
  end

  describe "Json component" do
    test "render/2 stringifies nested data structures" do
      data = %{
        name: "Test",
        active: true,
        count: 42,
        metrics: [1.5, 2.0],
        meta: %{tags: ["a", "b"]},
        none: nil
      }

      result = Json.render(data, indent: 2)
      assert is_list(result)
      str = IO.iodata_to_binary(result)
      assert String.contains?(str, "\"Test\"")
      assert String.contains?(str, "42")
      assert String.contains?(str, "true")
      assert String.contains?(str, "\"meta\"")
      assert String.contains?(str, "null")
    end

    test "render/2 handles empty structures" do
      assert IO.iodata_to_binary(Json.render(%{})) |> String.contains?("{}")
      assert IO.iodata_to_binary(Json.render([])) |> String.contains?("[]")
    end
  end

  describe "Separator component" do
    test "render/2 returns iodata with or without text" do
      result1 = Separator.render(nil, char: "-", width: 10)
      str1 = IO.iodata_to_binary(result1)
      assert String.contains?(str1, "----------")

      result2 = Separator.render("Middle", char: "=", width: 20)
      str2 = IO.iodata_to_binary(result2)
      assert String.contains?(str2, "Middle")
      assert String.contains?(str2, "=")
    end
  end
end
