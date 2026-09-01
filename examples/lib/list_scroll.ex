defmodule Alaja.Examples.ListScroll do
  @moduledoc """
  Scrollable list example. Use ↑/↓ to navigate, q to quit.
  """
  use Alaja.App

  alias Alaja.View.Node, as: V
  alias Alaja.{Components, Msg, Sub}

  @impl Alaja.App
  def init(_args) do
    items = Enum.map(1..50, &"Item #{&1}")
    state = %{
      list: Components.list_init(items, max_visible: 10)
    }
    {:ok, state}
  end

  @impl Alaja.App
  def update(msg, state) do
    case msg do
      %Msg.Key{key: "q"} -> {:halt, state}
      _ ->
        {:ok, new_list, cmds} = Components.list_update(state.list, msg)
        {:ok, %{state | list: new_list}, cmds}
    end
  end

  @impl Alaja.App
  def view(state) do
    V.column([
      V.text("List Scroll (↑/↓, q to quit)"),
      V.rule(),
      Components.list_view(state.list),
      V.rule(),
      V.status_bar("Selected: #{Enum.at(state.list.items, state.list.selected) || "(none)"}")
    ])
  end

  @impl Alaja.App
  def subscriptions(_state), do: [Sub.keypress()]
end
