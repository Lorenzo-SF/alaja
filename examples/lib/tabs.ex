defmodule Alaja.Examples.Tabs do
  @moduledoc """
  Tabbed interface example. Use ←/→ to switch tabs, q to quit.
  """
  use Alaja.App

  alias Alaja.View.Node, as: V
  alias Alaja.{Components, Msg, Sub}

  @impl Alaja.App
  def init(_args) do
    state = %{
      tabs: Components.tabs_init(["Home", "Settings", "About"])
    }
    {:ok, state}
  end

  @impl Alaja.App
  def update(msg, state) do
    case msg do
      %Msg.Key{key: "q"} -> {:halt, state}
      _ ->
        {:ok, new_tabs, cmds} = Components.tabs_update(state.tabs, msg)
        {:ok, %{state | tabs: new_tabs}, cmds}
    end
  end

  @impl Alaja.App
  def view(state) do
    active = Enum.at(state.tabs.labels, state.tabs.active)
    V.column([
      V.text("Tabbed Interface (←/→, q to quit)"),
      V.rule(),
      Components.tabs_view(state.tabs),
      V.rule(),
      V.box(V.text("You are on the '#{active}' tab."), border: :single, padding: 1),
      V.status_bar("active: #{active}")
    ])
  end

  @impl Alaja.App
  def subscriptions(_state), do: [Sub.keypress()]
end
