defmodule Alaja.Msg do
  @moduledoc """
  Event types delivered to an `Alaja.App` callback module.

  Each `Alaja.Msg.t/0` is one variant from the union defined below. Apps
  pattern-match on the struct type in `update/2`.

  ## Example

      def update(msg, state) do
        case msg do
          %Alaja.Msg.Key{key: "q"} -> {:halt, state}
          %Alaja.Msg.Key{key: "j", modifiers: [:ctrl]} -> {:ok, state + 1}
          %Alaja.Msg.Tick{} -> {:ok, state, [Alaja.Cmd.quit()]}
          _ -> {:ok, state}
        end
      end
  """

  alias Alaja.Msg.{Focus, Key, Mouse, Paste, Resize, Tick, Custom, Quit, Error}

  @type modifier :: :ctrl | :alt | :shift | :meta
  @type key_name :: String.t()
  @type mouse_action ::
          :press | :release | :move | :drag | :wheel_up | :wheel_down | :wheel_left | :wheel_right
  @type mouse_button :: :left | :right | :middle | :none

  @type t ::
          %Key{key: key_name(), modifiers: [modifier()], raw: binary()}
          | %Mouse{
              action: mouse_action(),
              button: mouse_button(),
              x: pos_integer(),
              y: pos_integer()
            }
          | %Resize{width: pos_integer(), height: pos_integer()}
          | %Paste{content: String.t()}
          | %Focus{id: term(), gain: boolean()}
          | %Tick{}
          | %Custom{name: atom(), payload: term()}
          | %Quit{}
          | %Error{kind: atom(), reason: term()}

  defmodule Key do
    @moduledoc "A keyboard event. `key` is the normalised name (e.g. `\"q\"`, `\"up\"`, `\"f1\"`)."
    defstruct [:key, modifiers: [], raw: ""]
    @type t :: %__MODULE__{key: String.t(), modifiers: [atom()], raw: binary()}
  end

  defmodule Mouse do
    @moduledoc "A mouse event with 1-based terminal coordinates."
    defstruct action: :press, button: :left, x: 1, y: 1
    @type t :: %__MODULE__{action: atom(), button: atom(), x: pos_integer(), y: pos_integer()}
  end

  defmodule Resize do
    @moduledoc "Terminal size change."
    defstruct width: 80, height: 24
    @type t :: %__MODULE__{width: pos_integer(), height: pos_integer()}
  end

  defmodule Paste do
    @moduledoc "Bracketed paste content."
    defstruct content: ""
    @type t :: %__MODULE__{content: String.t()}
  end

  defmodule Focus do
    @moduledoc "Focus gain/loss on a focusable id."
    defstruct id: nil, gain: true
    @type t :: %__MODULE__{id: term(), gain: boolean()}
  end

  defmodule Tick do
    @moduledoc "Periodic timer tick from `Alaja.Sub.tick/1`."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Custom do
    @moduledoc "App-defined custom event."
    defstruct name: nil, payload: nil
    @type t :: %__MODULE__{name: atom(), payload: term()}
  end

  defmodule Quit do
    @moduledoc "Quit request (e.g. from `Alaja.Cmd.quit()`)."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Error do
    @moduledoc "Subsystem error report (e.g. parse failure, backend failure)."
    defstruct kind: nil, reason: nil
    @type t :: %__MODULE__{kind: atom(), reason: term()}
  end

  @doc "Builds a `Key` event from raw bytes."
  @spec key(String.t(), keyword()) :: Key.t()
  def key(name, opts \\ []) when is_binary(name) do
    %Key{
      key: name,
      modifiers: Keyword.get(opts, :modifiers, []),
      raw: Keyword.get(opts, :raw, "")
    }
  end

  @doc "Builds a `Mouse` event."
  @spec mouse(atom(), atom(), pos_integer(), pos_integer()) :: Mouse.t()
  def mouse(action, button, x, y) when is_integer(x) and x > 0 and is_integer(y) and y > 0 do
    %Mouse{action: action, button: button, x: x, y: y}
  end

  @doc "Builds a `Resize` event."
  @spec resize(pos_integer(), pos_integer()) :: Resize.t()
  def resize(w, h) when is_integer(w) and w > 0 and is_integer(h) and h > 0 do
    %Resize{width: w, height: h}
  end

  @doc "Builds a `Tick` event."
  @spec tick() :: Tick.t()
  def tick, do: %Tick{}

  @doc "Builds a `Quit` event."
  @spec quit() :: Quit.t()
  def quit, do: %Quit{}

  @doc "Builds a `Custom` event."
  @spec custom(atom(), term()) :: Custom.t()
  def custom(name, payload) when is_atom(name), do: %Custom{name: name, payload: payload}
end
