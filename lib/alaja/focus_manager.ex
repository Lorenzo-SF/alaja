defmodule Alaja.FocusManager do
  @moduledoc """
  Manages focus across multiple components in a TUI app.

  The FocusManager holds a stack of focused component ids. The
  app's `update/2` can delegate key events to the focused component,
  and Tab / Shift+Tab rotate focus.

  ## Usage

      # In your app state
      defstruct [:focus, :components]

      # In init/1
      focus = Alaja.FocusManager.new([:sidebar, :main, :status])
      state = %{focus: focus, sidebar: ..., main: ..., status: ...}

      # In view/1 — render only the focused component differently
      def view(state) do
        ...
        border = if Alaja.FocusManager.focused?(state.focus, :sidebar) do
          [border: :single]
        else
          [border: :none]
        end
        Alaja.View.Node.box(sidebar_view, border)
      end

      # In update/2 — Tab rotates, others delegate
      def update(%Alaja.Msg.Key{key: "tab"}, state) do
        {:ok, %{state | focus: Alaja.FocusManager.next(state.focus)}, []}
      end

      def update(msg, state) do
        case Alaja.FocusManager.focused(state.focus) do
          :sidebar -> update_sidebar(msg, state)
          :main -> update_main(msg, state)
          :status -> update_status(msg, state)
        end
      end
  """

  defstruct ids: [], current: 0

  @type t :: %__MODULE__{
          ids: [atom()],
          current: non_neg_integer()
        }

  @doc "Creates a new FocusManager with the given component ids in order."
  @spec new([atom()]) :: t()
  def new(ids) when is_list(ids), do: %__MODULE__{ids: ids, current: 0}
  def new([]), do: %__MODULE__{ids: [], current: 0}

  @doc "Returns the currently focused component id."
  @spec focused(t()) :: atom() | nil
  def focused(%__MODULE__{ids: []}), do: nil

  def focused(%__MODULE__{ids: ids, current: current}) do
    Enum.at(ids, current)
  end

  @doc "Returns true if the given id is the focused one."
  @spec focused?(t(), atom()) :: boolean()
  def focused?(%__MODULE__{} = fm, id), do: focused(fm) == id

  @doc "Sets the focused component to the given id."
  @spec focus(t(), atom()) :: t()
  def focus(%__MODULE__{ids: ids} = fm, id) do
    case Enum.find_index(ids, &(&1 == id)) do
      nil -> fm
      idx -> %{fm | current: idx}
    end
  end

  @doc "Rotates focus to the next component (wraps around)."
  @spec next(t()) :: t()
  def next(%__MODULE__{ids: []} = fm), do: fm

  def next(%__MODULE__{ids: ids, current: current} = fm) do
    %{fm | current: rem(current + 1, length(ids))}
  end

  @doc "Rotates focus to the previous component (wraps around)."
  @spec prev(t()) :: t()
  def prev(%__MODULE__{ids: []} = fm), do: fm

  def prev(%__MODULE__{ids: ids, current: current} = fm) do
    max = length(ids)
    %{fm | current: rem(current - 1 + max, max)}
  end
end
