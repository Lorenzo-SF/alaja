defmodule Alaja.CLI.Smoke.ComponentsReturnBufferTest do
  @moduledoc """
  Sacred test: every component's `render/N` MUST return a `Buffer.t()`.

  This enforces the architectural principle:
    "Buffer is the cell engine and must be the heart of alaja."

  Before this rework, several components returned iodata or printed
  directly. That breaks the rule that all components are pure renderers
  producing composable Cell-based buffers.
  """
  use ExUnit.Case, async: true

  alias Alaja.Buffer

  describe "Components that MUST return Buffer.t()" do
    test "Components.Bar.render/3 returns Buffer.t()" do
      result = Alaja.Components.Bar.render(50, 100, color: :green)
      assert %Buffer{} = result
    end

    test "Components.Box.render/2 returns Buffer.t()" do
      result = Alaja.Components.Box.render("Hello", border: :single)
      assert %Buffer{} = result
    end

    test "Components.Box.render/2 with Buffer input returns Buffer.t()" do
      input = Alaja.Components.Bar.render(50, 100)
      result = Alaja.Components.Box.render(input, border: :single)
      assert %Buffer{} = result
    end

    test "Components.Header.render/2 returns Buffer.t()" do
      result = Alaja.Components.Header.render("Title")
      assert %Buffer{} = result
    end

    test "Components.Json.render/2 returns Buffer.t()" do
      result = Alaja.Components.Json.render(%{key: "value"})
      assert %Buffer{} = result
    end

    test "Components.Separator.render/2 returns Buffer.t()" do
      result = Alaja.Components.Separator.render("---")
      assert %Buffer{} = result
    end
  end

  describe "Components with broken signatures — must be fixed" do
    test "Components.AnimatedBar.render_frame/4 returns Buffer.t() (BUG: returns iodata)" do
      # render_frame/4 is called for each tick. It should return a Buffer
      # so we can compose with Box, Header, etc.
      result = Alaja.Components.AnimatedBar.render_frame(50, 100, 25, color: :green)
      assert %Buffer{} = result, "Expected Buffer.t(), got: #{inspect(result)}"
    end

    test "Components.Table.render/2 returns Buffer.t() (BUG: returns iodata)" do
      result =
        Alaja.Components.Table.render(
          headers: ["a", "b"],
          rows: [["1", "2"]],
          table_border: :single
        )

      assert %Buffer{} = result, "Expected Buffer.t(), got: #{inspect(result)}"
    end

    test "Components.Breadcrumbs.render/2 always returns Buffer.t() (BUG: returns | [])" do
      # Empty list should return empty Buffer, not []
      empty = Alaja.Components.Breadcrumbs.render([], color: :blue)
      assert %Buffer{} = empty, "Expected Buffer.t(), got: #{inspect(empty)}"

      # Non-empty should also return Buffer
      full = Alaja.Components.Breadcrumbs.render(["a", "b"], color: :blue)
      assert %Buffer{} = full, "Expected Buffer.t(), got: #{inspect(full)}"
    end

    test "Components.Pulsar.render_frame/3 returns Buffer.t() (BUG: returns iodata)" do
      result = Alaja.Components.Pulsar.render_frame("text", 0, width: 40)
      assert %Buffer{} = result, "Expected Buffer.t(), got: #{inspect(result)}"
    end

    test "Components.Message.render/1 exists (MISSING component)" do
      msg = %Alaja.Structures.MessageInfo{
        chunks: [
          %Alaja.Structures.ChunkText{text: "Hello", color: :cyan},
          %Alaja.Structures.ChunkText{text: "World", color: :green}
        ],
        align: :left
      }

      Code.ensure_loaded(Alaja.Components.Message)

      assert :render in (Alaja.Components.Message.module_info(:exports) |> Keyword.keys()),
             "Alaja.Components.Message.render/1 is missing — must be created"

      result = Alaja.Components.Message.render(msg)
      assert %Buffer{} = result
    end
  end

  describe "Components composition (Buffer-in / Buffer-out)" do
    test "Box can wrap a Bar buffer" do
      bar = Alaja.Components.Bar.render(75, 100)
      boxed = Alaja.Components.Box.render(bar, border: :rounded)
      assert %Buffer{} = boxed
    end

    test "Box can wrap a Header buffer" do
      header = Alaja.Components.Header.render("Title", subtitle: "Sub")
      boxed = Alaja.Components.Box.render(header, border: :single)
      assert %Buffer{} = boxed
    end
  end
end
