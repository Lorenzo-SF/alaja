#!/usr/bin/env elixir
# Run with:  elixir -S mix run examples/list_scroll.exs

{:ok, _} = Application.ensure_all_started(:alaja)
{:ok, _} = Alaja.Examples.ListScroll.start_link(Alaja.Examples.ListScroll, backend: :tty)

Process.sleep(:infinity)
