defmodule Bench.VsOwl do
  @moduledoc """
  Compare alaja's table renderer against Owl's.

  Owl is NOT a default dependency of alaja. To run this benchmark:

      1. Add `{:owl, "~> 0.13"}` to `mix.exs` (optional dev dep)
      2. `mix deps.get`
      3. `mix run benchmarks/vs_owl.exs`

  The benchmark intentionally matches the API surface so the comparison
  is apples-to-apples: same headers, same row data, same border style
  (rounded for alaja, default for Owl).

  Output: standard Benchee report with `alaja` vs `owl` rows.
  """

  require Owl

  Benchee.run(%{
    "alaja table 5x5" => fn ->
      Alaja.Components.Table.render(
        headers: ["name", "status", "owner", "env", "updated"],
        rows: [
          ["api", "ok", "alice", "prod", "2026-08-05"],
          ["web", "degraded", "bob", "prod", "2026-08-05"],
          ["worker", "ok", "alice", "stg", "2026-08-04"],
          ["db", "ok", "carol", "prod", "2026-08-03"],
          ["cron", "ok", "dave", "dev", "2026-08-02"]
        ],
        table_border: :rounded
      )
      |> Alaja.Buffer.to_iodata()
      |> IO.iodata_to_binary()
    end,
    "owl table 5x5" => fn ->
      Owl.Table.new(
        [
          ["api", "ok", "alice", "prod", "2026-08-05"],
          ["web", "degraded", "bob", "prod", "2026-08-05"],
          ["worker", "ok", "alice", "stg", "2026-08-04"],
          ["db", "ok", "carol", "prod", "2026-08-03"],
          ["cron", "ok", "dave", "dev", "2026-08-02"]
        ],
        header: ["name", "status", "owner", "env", "updated"]
      )
      |> Owl.IO.plain()
    end
  })
end