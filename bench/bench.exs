defmodule Alaja.Bench do
  @moduledoc """
  Performance benchmarks for alaja 3.0.

  Run with:

      elixir -S mix run bench/bench.exs

  Reports microseconds per call for each operation.
  """

  alias Alaja.{Frame, Layout, Renderer, Input, View.Node, as: V}

  def run do
    IO.puts("Alaja 3.0 benchmarks")
    IO.puts("====================")
    bench_layout_render()
    bench_renderer_diff()
    bench_input_parse()
    bench_text_width()
    IO.puts("done")
  end

  defp bench_layout_render do
    node =
      V.column([
        V.text("header"),
        V.rule(),
        V.row([V.text("a"), V.text("bb"), V.text("ccc")]),
        V.box(V.text("inner"), border: :single, padding: 1),
        V.status_bar("status")
      ])

    {us, _} = :timer.tc(fn ->
      Enum.each(1..1000, fn _ -> Layout.render_to_frame(node, 80, 24) end)
    end)

    IO.puts("Layout.render_to_frame/3  80x24 x 1000  = #{div(us, 1000)} ms (#{div(us, 1000)} µs/call)")
  end

  defp bench_renderer_diff do
    f1 = Layout.render_to_frame(V.text("hello world"), 80, 24)
    f2 = Layout.render_to_frame(V.text("hello WORLD"), 80, 24)

    {us, _} = :timer.tc(fn ->
      Enum.each(1..10_000, fn _ -> Renderer.diff(f1, f2) end)
    end)

    IO.puts("Renderer.diff/2  10k calls  = #{div(us, 1000)} ms (#{div(us, 10_000)} µs/call)")
  end

  defp bench_input_parse do
    inputs = [
      "hello",
      "\e[A\e[B\e[C\e[D",
      "\e[97;5u\e[97;5u\e[97;5u",
      "\e[1;2Z"
    ]

    {us, _} = :timer.tc(fn ->
      Enum.each(1..10_000, fn i ->
        Input.parse(Enum.at(inputs, rem(i, length(inputs))))
      end)
    end)

    IO.puts("Input.parse/1  10k calls  = #{div(us, 1000)} ms (#{div(us, 10_000)} µs/call)")
  end

  defp bench_text_width do
    samples = ["hello", "こんにちは", "mixed 你好 world", "ascii only"]

    {us, _} = :timer.tc(fn ->
      Enum.each(1..100_000, fn i ->
        Alaja.Text.width(Enum.at(samples, rem(i, length(samples))))
      end)
    end)

    IO.puts("Text.width/1  100k calls  = #{us} µs (#{div(us, 100_000)} µs/call)")
  end
end

Alaja.Bench.run()
