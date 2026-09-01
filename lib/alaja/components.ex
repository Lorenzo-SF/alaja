defmodule Alaja.Components do
  @moduledoc """
  Stateful UI components for alaja 3.0.

  Each component is a pair of:

    * `init/1` — returns the initial state.
    * `view/1` — returns a `View.Node.t()`.
    * `update/2` — applies a `Msg.t()` and returns `{:ok, new_state, [Cmd.t()]}`.

  Components maintain their own state (scroll position, selected item,
  focus). Apps compose them by holding the state in their top-level
  state and calling the component's `view/1` and `update/2` helpers.

  ## Available components

    * `list/1` — a scrollable, focusable list of items.
    * `tabs/1` — a tabbed interface.
    * `log/1` — append-only log with auto-scroll.
    * `progress/1` — a progress bar.
  """

  # ── List ──────────────────────────────────────────────────────────────────

  defmodule ListState do
    @moduledoc false
    defstruct items: [], selected: 0, offset: 0, focused: false, max_visible: 10

    @type t :: %__MODULE__{
            items: [String.t()],
            selected: non_neg_integer(),
            offset: non_neg_integer(),
            focused: boolean(),
            max_visible: pos_integer()
          }
  end

  @doc "Builds a new list component state."
  @spec list_init([String.t()], keyword()) :: ListState.t()
  def list_init(items, opts \\ []) do
    %ListState{
      items: items,
      selected: 0,
      offset: 0,
      focused: Keyword.get(opts, :focused, false),
      max_visible: Keyword.get(opts, :max_visible, 10)
    }
  end

  @doc "Renders a list as a View.Node."
  @spec list_view(ListState.t()) :: Alaja.View.Node.t()
  def list_view(%ListState{} = s) do
    visible = Enum.slice(s.items, s.offset, s.max_visible)

    rows =
      visible
      |> Enum.with_index()
      |> Enum.map(fn {item, idx} ->
        global_idx = s.offset + idx
        marker = if global_idx == s.selected, do: ">", else: " "
        style = if global_idx == s.selected, do: [reverse: true], else: []
        Alaja.View.Node.text("#{marker} #{item}", style: style)
      end)

    Alaja.View.Node.column(rows)
  end

  @doc "Updates a list component from a Msg."
  @spec list_update(ListState.t(), Alaja.Msg.t()) :: {:ok, ListState.t(), [Alaja.Cmd.t()]}
  def list_update(%ListState{} = s, %Alaja.Msg.Key{key: "up"}) do
    new_selected = max(s.selected - 1, 0)
    new_offset = compute_offset(s.items, new_selected, s.offset, s.max_visible)
    {:ok, %{s | selected: new_selected, offset: new_offset}, []}
  end

  def list_update(%ListState{} = s, %Alaja.Msg.Key{key: "down"}) do
    max = max(length(s.items) - 1, 0)
    new_selected = min(s.selected + 1, max)
    new_offset = compute_offset(s.items, new_selected, s.offset, s.max_visible)
    {:ok, %{s | selected: new_selected, offset: new_offset}, []}
  end

  def list_update(%ListState{} = s, _msg), do: {:ok, s, []}

  defp compute_offset(_items, selected, offset, max_visible) do
    cond do
      selected < offset -> selected
      selected >= offset + max_visible -> selected - max_visible + 1
      true -> offset
    end
  end

  # ── Tabs ──────────────────────────────────────────────────────────────────

  defmodule TabsState do
    @moduledoc false
    defstruct labels: [], active: 0
    @type t :: %__MODULE__{labels: [String.t()], active: non_neg_integer()}
  end

  @spec tabs_init([String.t()]) :: TabsState.t()
  def tabs_init(labels), do: %TabsState{labels: labels, active: 0}

  @spec tabs_view(TabsState.t()) :: Alaja.View.Node.t()
  def tabs_view(%TabsState{} = s) do
    headers =
      s.labels
      |> Enum.with_index()
      |> Enum.map(fn {label, idx} ->
        if idx == s.active do
          Alaja.View.Node.text("[ #{label} ]", style: [reverse: true])
        else
          Alaja.View.Node.text("  #{label}  ")
        end
      end)

    Alaja.View.Node.row(headers)
  end

  @spec tabs_update(TabsState.t(), Alaja.Msg.t()) :: {:ok, TabsState.t(), [Alaja.Cmd.t()]}
  def tabs_update(%TabsState{labels: labels} = s, %Alaja.Msg.Key{key: "right"}) do
    {:ok, %{s | active: rem(s.active + 1, max(length(labels), 1))}, []}
  end

  def tabs_update(%TabsState{labels: labels} = s, %Alaja.Msg.Key{key: "left"}) do
    max = max(length(labels), 1)
    {:ok, %{s | active: rem(s.active - 1 + max, max)}, []}
  end

  def tabs_update(s, _), do: {:ok, s, []}

  # ── Log ───────────────────────────────────────────────────────────────────

  defmodule LogState do
    @moduledoc false
    defstruct lines: [], max_lines: 1000
    @type t :: %__MODULE__{lines: [String.t()], max_lines: pos_integer()}
  end

  @spec log_init(keyword()) :: LogState.t()
  def log_init(opts \\ []), do: %LogState{max_lines: Keyword.get(opts, :max_lines, 1000)}

  @doc "Appends a line to the log."
  @spec log_append(LogState.t(), String.t()) :: LogState.t()
  def log_append(%LogState{lines: lines, max_lines: max} = s, line) do
    new_lines = Enum.take(lines ++ [line], -max)
    %{s | lines: new_lines}
  end

  @spec log_view(LogState.t()) :: Alaja.View.Node.t()
  def log_view(%LogState{lines: lines}) do
    Alaja.View.Node.column(Enum.map(lines, &Alaja.View.Node.text/1))
  end

  @spec log_update(LogState.t(), Alaja.Msg.t()) :: {:ok, LogState.t(), [Alaja.Cmd.t()]}
  def log_update(s, _), do: {:ok, s, []}

  # ── Progress ──────────────────────────────────────────────────────────────

  defmodule ProgressState do
    @moduledoc false
    defstruct current: 0, total: 100, width: 20, label: ""

    @type t :: %__MODULE__{
            current: non_neg_integer(),
            total: pos_integer(),
            width: pos_integer(),
            label: String.t()
          }
  end

  @spec progress_init(keyword()) :: ProgressState.t()
  def progress_init(opts) do
    %ProgressState{
      current: Keyword.get(opts, :current, 0),
      total: Keyword.get(opts, :total, 100),
      width: Keyword.get(opts, :width, 20),
      label: Keyword.get(opts, :label, "")
    }
  end

  @spec progress_set(ProgressState.t(), non_neg_integer()) :: ProgressState.t()
  def progress_set(%ProgressState{} = s, current) do
    %{s | current: min(max(current, 0), s.total)}
  end

  @spec progress_view(ProgressState.t()) :: Alaja.View.Node.t()
  def progress_view(%ProgressState{current: c, total: t, width: w, label: lbl}) do
    pct = if t > 0, do: div(c * 100, t), else: 0
    filled = if t > 0, do: div(c * w, t), else: 0
    bar = String.duplicate("█", filled) <> String.duplicate("░", w - filled)
    text = "#{lbl} [#{bar}] #{pct}%"

    Alaja.View.Node.text(text)
  end

  @spec progress_update(ProgressState.t(), Alaja.Msg.t()) ::
          {:ok, ProgressState.t(), [Alaja.Cmd.t()]}
  def progress_update(s, _), do: {:ok, s, []}
end
