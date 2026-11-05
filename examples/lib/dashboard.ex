defmodule Alaja.Examples.Dashboard do
  @moduledoc """
  Dashboard with progress bars. Use +/- to advance, q to quit.
  """
  use Alaja.App

  alias Alaja.View.Node, as: V
  alias Alaja.{Components, Msg, Sub}

  @impl Alaja.App
  def init(_args) do
    state = %{
      download: Components.progress_init(current: 30, total: 100, width: 25, label: "Download"),
      upload: Components.progress_init(current: 75, total: 100, width: 25, label: "Upload  "),
      render: Components.progress_init(current: 12, total: 60, width: 25, label: "Render  "),
      tick_count: 0
    }
    {:ok, state}
  end

  @impl Alaja.App
  def update(msg, state) do
    case msg do
      %Msg.Key{key: "q"} -> {:halt, state}
      %Msg.Key{key: "+"} -> bump_all(state)
      %Msg.Key{key: "-"} -> bump_all(state, -1)
      %Msg.Tick{} ->
        new_state = bump_all(state, 1, :tick)
        {:ok, new_state, []}
      _ -> {:ok, state, []}
    end
  end

  defp bump_all(state, delta \\ 5, mode \\ :key) do
    new_dl = Components.progress_set(state.download, state.download.current + delta)
    new_up = Components.progress_set(state.upload, state.upload.current + delta)
    new_rn = Components.progress_set(state.render, state.render.current + delta)
    %{state | download: new_dl, upload: new_up, render: new_rn, tick_count: state.tick_count + 1}
  end

  @impl Alaja.App
  def view(state) do
    V.column([
      V.text("Dashboard  (ticks: #{state.tick_count}, +/- to bump, q to quit)"),
      V.rule(),
      Components.progress_view(state.download),
      Components.progress_view(state.upload),
      Components.progress_view(state.render),
      V.status_bar("dashboard ready")
    ])
  end

  @impl Alaja.App
  def subscriptions(_state), do: [Sub.keypress(), Sub.tick(500)]
end
