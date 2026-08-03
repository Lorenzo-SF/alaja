defmodule Alaja.View.Node do
  @moduledoc """
  A node in the View tree. The layout engine measures and arranges nodes
  against the frame constraints; the renderer draws them onto a frame.

  `tag` is the node kind (`:text`, `:column`, `:row`, `:box`, etc.).
  `props` carries node-specific options (border, padding, etc.).
  `children` are nested nodes (for containers). `meta` is arbitrary
  metadata used by the app (e.g. an `:id` for focus tracking).
  """

  @type id :: term()
  @type prop :: {atom(), term()}
  @type props :: [prop()]

  @type t :: %__MODULE__{
          tag: atom(),
          props: props(),
          children: [t()],
          meta: map()
        }

  defstruct tag: :node, props: [], children: [], meta: %{}

  @doc "Builds a text node."
  @spec text(String.t(), keyword()) :: t()
  def text(content, opts \\ []) when is_binary(content) do
    %__MODULE__{tag: :text, props: [{:content, content} | opts], children: []}
  end

  @doc "Builds a column container (children stacked vertically)."
  @spec column([t()], keyword()) :: t()
  def column(children, opts \\ []) when is_list(children) do
    %__MODULE__{tag: :column, props: opts, children: children}
  end

  @doc "Builds a row container (children placed horizontally)."
  @spec row([t()], keyword()) :: t()
  def row(children, opts \\ []) when is_list(children) do
    %__MODULE__{tag: :row, props: opts, children: children}
  end

  @doc "Builds a box container with border + padding."
  @spec box(t(), keyword()) :: t()
  def box(child, opts \\ []) do
    %__MODULE__{tag: :box, props: opts, children: [child]}
  end

  @doc "Builds a rule (horizontal line)."
  @spec rule(keyword()) :: t()
  def rule(opts \\ []), do: %__MODULE__{tag: :rule, props: opts, children: []}

  @doc "Builds a status bar at the bottom of the frame."
  @spec status_bar(String.t(), keyword()) :: t()
  def status_bar(content, opts \\ []) when is_binary(content) do
    %__MODULE__{
      tag: :status_bar,
      props: [{:content, content} | opts],
      children: []
    }
  end

  @doc """
  Builds a grid node — children arranged in a fixed number of columns.
  Requires `:columns` in opts.
  """
  @spec grid([t()], keyword()) :: t()
  def grid(children, opts \\ []) when is_list(children) do
    %__MODULE__{tag: :grid, props: opts, children: children}
  end

  @doc "Returns the metadata for this node."
  @spec meta(t(), id()) :: map()
  def meta(%__MODULE__{meta: meta}, id), do: Map.get(meta, id)

  @doc "Sets a metadata key."
  @spec put_meta(t(), id(), term()) :: t()
  def put_meta(%__MODULE__{} = node, key, value) do
    %{node | meta: Map.put(node.meta, key, value)}
  end
end
