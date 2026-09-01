defmodule Alaja.Examples.Demo do
  @moduledoc """
  A combined demo showing all built-in components: progress bars,
  tabs, list, and log — with focus rotation between them.

  Keys:
    * Tab / Shift+Tab — rotate focus between panels
    * Arrow keys — interact with the focused panel
    * +/- — bump progress bars
    * l — append a log line
    * q — quit
  """
  use Alaja.App

  alias Alaja.View.Node, as: V
  alias Alaja.{Components, FocusManager, Msg, Sub}

  defmodule Panel do
    defstruct [:id, :type, :state]
  end

  @impl Alaja.App
  def init(_args) do
    state = %{
      focus: FocusManager.new([:progress, :tabs, :list, :log]),
      progress: %{
        download: Components.progress_init(current: 30, total: 100, width: 18, label: "Download"),
        upload: Components.progress_init(current: 75, total: 100, width: 18, label: "Upload  "),
        render: Components.progress_init(current: 12, total: 60, width: 18, label: "Render  ")
      },
      tabs: Components.tabs_init(["Home", "Settings", "About"]),
      list: Components.list_init(Enum.map(1..20, &"Row #{&1}"), max_visible: 5),
      log: Components.log_init(max_lines: 50) |> tap(&seed_log/1),
      counter: 0
    }

    {:ok, state}
  end

  defp seed_log(log) do
    log
    |> Components.log_append("demo started")
    |> Components.log_append("press Tab to rotate focus")
    |> Components.log_append("press +/- to bump progress")
    |> Components.log_append("press q to quit")
  end

  @impl Alaja.App
  def update(msg, state) do
    case msg do
      %Msg.Key{key: "q"} -> {:halt, state}
      %Msg.Key{key: "tab"} -> {:ok, %{state | focus: FocusManager.next(state.focus)}, []}
      %Msg.Key{key: "shift-tab"} -> {:ok, %{state | focus: FocusManager.prev(state.focus)}, []}
      %Msg.Tick{} -> auto_update(state, msg)
      _ -> delegate(msg, state)
    end
  end

  defp auto_update(state, _msg) do
    new_progress =
      Map.new(state.progress, fn {k, p} ->
        {k, Components.progress_set(p, rem(p.current + 1, p.total + 1))}
      end)

    new_log = Components.log_append(state.log, "[#{state.counter}] auto-update")
    {:ok, %{state | progress: new_progress, log: new_log, counter: state.counter + 1}, []}
  end

  defp delegate(msg, state) do
    case FocusManager.focused(state.focus) do
      :progress -> update_progress(msg, state)
      :tabs -> update_tabs(msg, state)
      :list -> update_list(msg, state)
      :log -> update_log(msg, state)
      _ -> {:ok, state, []}
    end
  end

  defp update_progress(msg, state) do
    delta =
      case msg do
        %Msg.Key{key: "+"} -> 5
        %Msg.Key{key: "="} -> 5
        %Msg.Key{key: "-"} -> -5
        _ -> 0
      end

    if delta == 0 do
      {:ok, state, []}
    else
      new_progress =
        Map.new(state.progress, fn {k, p} -> {k, Components.progress_set(p, p.current + delta)} end)

      {:ok, %{state | progress: new_progress}, []}
    end
  end

  defp update_tabs(msg, state) do
    {:ok, new_tabs, cmds} = Components.tabs_update(state.tabs, msg)
    {:ok, %{state | tabs: new_tabs}, cmds}
  end

  defp update_list(msg, state) do
    {:ok, new_list, cmds} = Components.list_update(state.list, msg)
    {:ok, %{state | list: new_list}, cmds}
  end

  defp update_log(%Msg.Key{key: "l"}, state) do
    {:ok, %{state | log: Components.log_append(state.log, "[#{state.counter}] manual log line")}, []}
  end

  def update_log(_msg, state), do: {:ok, state, []}

  @impl Alaja.App
  def view(state) do
    V.column([
      V.text("Alaja 3.0 Demo — Tab to switch panels, q to quit"),
      V.rule(),
      V.row([
        box_panel(state, :progress, "Progress", render_progress(state)),
        V.text("  "),
        box_panel(state, :tabs, "Tabs", V.column([Components.tabs_view(state.tabs), V.text(""), V.text("active: #{Enum.at(state.tabs.labels, state.tabs.active)}")]))
      ]),
      V.row([
        box_panel(state, :list, "List", Components.list_view(state.list)),
        V.text("  "),
        box_panel(state, :log, "Log", Components.log_view(state.log))
      ]),
      V.status_bar("focus: #{FocusManager.focused(state.focus)}  |  ticks: #{state.counter}")
    ])
  end

  defp render_progress(state) do
    V.column([
      Components.progress_view(state.progress.download),
      Components.progress_view(state.progress.upload),
      Components.progress_view(state.progress.render)
    ])
  end

  defp box_panel(state, id, title, content) do
    focused = FocusManager.focused?(state.focus, id)
    border = if focused, do: [border: :single, padding: 1], else: [border: :none]

    label = if focused, do: "[#{title}]", else: title
    V.box(content, border ++ [padding: 0])
    |> tap(fn _ -> :ok end)
  end

  @impl Alaja.App
  def subscriptions(_state), do: [Sub.keypress(), Sub.tick(1000)]
end
