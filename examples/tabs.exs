#!/usr/bin/env elixir
# Run with:  elixir -S mix run examples/tabs.exs

{:ok, _} = Application.ensure_all_started(:alaja)
{:ok, _} = Alaja.Examples.Tabs.start_link(Alaja.Examples.Tabs, backend: :tty)

Process.sleep(:infinity)
