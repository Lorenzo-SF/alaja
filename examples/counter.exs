#!/usr/bin/env elixir
# Run with:  elixir -S mix run examples/counter.exs

{:ok, _} = Application.ensure_all_started(:alaja)
{:ok, _} = Alaja.Examples.Counter.start_link(Alaja.Examples.Counter, backend: :tty)

Process.sleep(:infinity)
