defmodule BenchCase do
  @moduledoc false

  # Wraps a side-effectful function so the bench iteration does not flood
  # stdout. Each iteration captures into a binary (cheap) and discards it.
  def silent(name, side_effect_fun) do
    Benchee.run(%{
      name => fn -> ExUnit.CaptureIO.capture_io(side_effect_fun) end
    })
  end

  def pure(name, fun) do
    Benchee.run(%{name => fun})
  end
end

defmodule Bench.Alaja do
  @moduledoc """
  Internal benchmarks for the alaja renderer.

  Run with:

      mix run benchmarks/alaja.exs

  Measures alaja against itself across configurations (small table, wide
  table, many rows, colored message, bordered box). Side-effectful
  components are wrapped in `capture_io` so they don't flood stdout.

  See `vs_owl.exs` for a comparison against Owl (requires Owl as an
  optional dev dependency).
  """

  BenchCase.pure("alaja: small table 5x3", fn ->
    Alaja.Components.Table.render(
      headers: ["name", "status", "owner"],
      rows: [
        ["api", "ok", "alice"],
        ["web", "ok", "bob"],
        ["worker", "ok", "alice"],
        ["db", "ok", "carol"],
        ["cron", "ok", "dave"]
      ],
      table_border: :rounded
    )
    |> Alaja.Buffer.to_iodata()
    |> IO.iodata_to_binary()
  end)

  BenchCase.pure("alaja: wide table 3x10", fn ->
    Alaja.Components.Table.render(
      headers: ["c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10"],
      rows: [
        ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"],
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"],
        ["x", "y", "z", "w", "v", "u", "t", "s", "r", "q"]
      ],
      table_border: :rounded
    )
    |> Alaja.Buffer.to_iodata()
    |> IO.iodata_to_binary()
  end)

  rows100 = for i <- 1..100, do: ["row-#{i}", "status-#{rem(i, 5)}", "user-#{rem(i, 7)}"]

  BenchCase.pure("alaja: 100 rows table", fn ->
    Alaja.Components.Table.render(
      headers: ["name", "status", "user"],
      rows: rows100,
      table_border: :ascii
    )
    |> Alaja.Buffer.to_iodata()
    |> IO.iodata_to_binary()
  end)

  BenchCase.silent("alaja: success message", fn ->
    Alaja.CLI.Commands.Show.Message.run(["success", "Deploy completado"])
  end)

  BenchCase.silent("alaja: header + subtitle", fn ->
    Alaja.CLI.Commands.Show.Header.run(["Bench header", "--subtitle", "subtitle"])
  end)

  BenchCase.silent("alaja: separator", fn ->
    Alaja.CLI.Commands.Show.Separator.run(["Bench section"])
  end)

  BenchCase.silent("alaja: gradient", fn ->
    Alaja.CLI.Commands.Show.Gradient.run(["Benchmarking", "--from", "red", "--to", "blue"])
  end)
end