defmodule Alaja.App.CounterExample do
  @moduledoc false
  use Alaja.App

  alias Alaja.View.Node, as: V

  @impl Alaja.App
  def init(_args), do: {:ok, 0}

  @impl Alaja.App
  def update(msg, n) do
    case msg do
      %Alaja.Msg.Key{key: "q"} -> {:halt, n}
      %Alaja.Msg.Key{key: "+"} -> {:ok, n + 1}
      %Alaja.Msg.Key{key: "-"} -> {:ok, max(n - 1, 0)}
      %Alaja.Msg.Tick{} -> {:ok, n, [Alaja.Cmd.quit()]}
      _ -> {:ok, n}
    end
  end

  @impl Alaja.App
  def view(n) do
    V.column([
      V.text("Counter: #{n}"),
      V.status_bar("Press +/- to change, q to quit")
    ])
  end

  @impl Alaja.App
  def subscriptions(_n), do: []
end

defmodule Alaja.AppTest do
  use ExUnit.Case

  alias Alaja.{App, Msg}
  alias Alaja.View.Node

  setup do
    {:ok, app} =
      App.start_link(
        {Alaja.App.CounterExample, []},
        backend: :test,
        backend_opts: [width: 40, height: 10]
      )

    on_exit(fn ->
      if Process.alive?(app), do: App.stop(app)
    end)

    {:ok, app: app}
  end

  test "init returns the initial state", %{app: app} do
    # state snapshot may need a moment; do a small sync
    Process.sleep(10)
    assert App.state(app) == 0
  end

  test "view renders the initial counter", %{app: app} do
    Process.sleep(10)
    view = App.view(app)
    assert %Node{tag: :column} = view
  end

  test "Key msg increments state", %{app: app} do
    Process.sleep(10)
    App.update(app, Msg.key("+"))
    Process.sleep(20)
    assert App.state(app) == 1

    App.update(app, Msg.key("+"))
    Process.sleep(20)
    assert App.state(app) == 2
  end

  test "Key msg decrements state (with floor at 0)", %{app: app} do
    Process.sleep(10)
    App.update(app, Msg.key("-"))
    Process.sleep(20)
    assert App.state(app) == 0
  end

  test "Quit msg halts the app", %{app: app} do
    Process.sleep(10)
    App.update(app, Msg.quit())
    # wait for the app to stop
    :ok = wait_dead(app, 500)
  end

  test "Tick triggers Cmd.quit", %{app: app} do
    Process.sleep(10)
    App.update(app, Msg.tick())
    :ok = wait_dead(app, 500)
  end

  test "subscriptions are attached at init", %{app: app} do
    Process.sleep(10)
    # counter example returns [] — no subs
    assert Process.alive?(app)
  end

  test "start_link with module atom (no args)", %{app: _app} do
    defmodule CounterExampleNoArgs do
      @moduledoc false
      use Alaja.App

      alias Alaja.View.Node, as: V

      @impl Alaja.App
      def init(_args), do: {:ok, 0}

      @impl Alaja.App
      def update(_msg, n), do: {:ok, n}

      @impl Alaja.App
      def view(n), do: V.text("n=#{n}")

      @impl Alaja.App
      def subscriptions(_n), do: []
    end

    {:ok, app2} =
      App.start_link(
        CounterExampleNoArgs,
        backend: :test,
        backend_opts: [width: 40, height: 10]
      )

    on_exit(fn ->
      if Process.alive?(app2), do: App.stop(app2)
    end)

    Process.sleep(10)
    assert App.state(app2) == 0
  end

  defp wait_dead(pid, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_dead(pid, deadline)
  end

  defp do_wait_dead(pid, deadline) do
    if Process.alive?(pid) do
      if System.monotonic_time(:millisecond) > deadline do
        {:error, :timeout}
      else
        Process.sleep(10)
        do_wait_dead(pid, deadline)
      end
    else
      :ok
    end
  end
end
