#!/usr/bin/env elixir
# Run with:  elixir -S mix run examples/dashboard.exs

{:ok, _} = Application.ensure_all_started(:alaja)
{:ok, _} = Alaja.Examples.Dashboard.start_link(Alaja.Examples.Dashboard, backend: :tty)

Process.sleep(:infinity)
