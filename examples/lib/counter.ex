defmodule Alaja.Examples.Counter do
  @moduledoc """
  A minimal counter example. Press `+`/`-` to change, `q` to quit.

  Run with:

      elixir -S mix run examples/counter.exs
  """
  use Alaja.App

  alias Alaja.View.Node, as: V
  alias Alaja.{Msg, Sub}

  @impl Alaja.App
  def init(_args), do: {:ok, 0}

  @impl Alaja.App
  def update(msg, n) do
    case msg do
      %Msg.Key{key: "q"} -> {:halt, n}
      %Msg.Key{key: "+"} -> {:ok, n + 1}
      %Msg.Key{key: "="} -> {:ok, n + 1}
      %Msg.Key{key: "-"} -> {:ok, max(n - 1, 0)}
      _ -> {:ok, n}
    end
  end

  @impl Alaja.App
  def view(n) do
    V.column([
      V.text(""),
      V.text("    ╔════════════════════════╗"),
      V.text("    ║   Counter: #{pad(n)}   ║"),
      V.text("    ╚════════════════════════╝"),
      V.text(""),
      V.text("  +  increment  -  decrement  q  quit"),
      V.status_bar("ready")
    ])
  end

  @impl Alaja.App
  def subscriptions(_n), do: [Sub.keypress()]

  defp pad(n) when n < 10, do: " #{n} "
  defp pad(n) when n < 100, do: " #{n}"
  defp pad(n), do: "#{n}"
end
