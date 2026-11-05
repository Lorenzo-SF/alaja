# Alaja 3.0 Examples

This directory contains runnable TUI examples demonstrating the alaja
3.0 API. Each example uses `Alaja.App` (the TEA-style runtime) and
composes the built-in `Alaja.Components` and `Alaja.FocusManager`.

## Run

    # Counter
    elixir -S mix run examples/counter.exs

    # ListScroll
    elixir -S mix run examples/list_scroll.exs

    # Tabs
    elixir -S mix run examples/tabs.exs

    # Dashboard
    elixir -S mix run examples/dashboard.exs

## What's in each

| File | Module | Demonstrates |
|------|--------|--------------|
| `counter.exs` | `Alaja.Examples.Counter` | Minimal app: key events, state transitions, status bar. |
| `list_scroll.exs` | `Alaja.Examples.ListScroll` | `Alaja.Components.ListState` with up/down navigation. |
| `tabs.exs` | `Alaja.Examples.Tabs` | `Alaja.Components.TabsState` with left/right rotation. |
| `dashboard.exs` | `Alaja.Examples.Dashboard` | Multiple `ProgressState` + `Sub.tick/1` for auto-update. |

## Architecture

Each example follows the same shape:

    defmodule MyApp do
      use Alaja.App

      @impl Alaja.App
      def init(_args), do: {:ok, initial_state}

      @impl Alaja.App
      def update(msg, state) do
        # ...
      end

      @impl Alaja.App
      def view(state) do
        Alaja.View.Node.column([...])
      end

      @impl Alaja.App
      def subscriptions(_state), do: []
    end

    # Run with: Alaja.App.start_link({MyApp, []}, backend: :tty)
