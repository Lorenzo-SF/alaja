#!/usr/bin/env elixir
# Run with:  elixir -S mix run examples/demo.exs

{:ok, _} = Application.ensure_all_started(:alaja)
{:ok, _} = Alaja.Examples.Demo.start_link(Alaja.Examples.Demo, backend: :tty)

Process.sleep(:infinity)
