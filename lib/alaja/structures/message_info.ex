defmodule Alaja.Structures.MessageInfo do
  @moduledoc """
  Contains all information related to message printing.

  ## Fields

  - `chunks`: List of ChunkText to print
  - `align`: Alignment (:left, :center, :right, :justified)
  - `padding`: Padding (integer or tuple {top, right, bottom, left})
  - `add_line`: Additional lines (:before, :after, :both, :none)
  - `raw_coords`: Coordinates for raw mode {x, y}

  ## Examples

      iex> MessageInfo.new([ChunkText.new("Hello")])
      %MessageInfo{chunks: [...], align: :left, padding: 0, ...}

      iex> MessageInfo.new([ChunkText.new("Hello")], align: :center, padding: 2)
      %MessageInfo{chunks: [...], align: :center, padding: 2, ...}

  """

  alias Alaja.Structures.ChunkText

  @type align :: :left | :center | :right | :justified
  @type add_line :: :before | :after | :both | :none
  @type padding :: integer() | {integer(), integer(), integer(), integer()}

  @type t :: %__MODULE__{
          chunks: list(ChunkText.t()),
          align: align(),
          padding: padding(),
          add_line: add_line(),
          raw_coords: {integer(), integer()} | nil
        }

  defstruct chunks: [],
            align: :left,
            padding: 0,
            add_line: :none,
            raw_coords: nil

  @valid_aligns [:left, :center, :right, :justified]
  @valid_add_lines [:before, :after, :both, :none]

  @doc """
  Creates a new MessageInfo structure.

  ## Parameters

  - `chunks` - List of ChunkText or strings (automatically converted)
  - `opts` - Options:
    - `:align` - Alignment (default: :left)
    - `:padding` - Padding (default: 0)
    - `:add_line` - Additional lines (default: :none)
    - `:raw_coords` - Coordinates for raw mode (default: nil)

  ## Examples

      iex> MessageInfo.new(["Hello", " world"])
      %MessageInfo{chunks: [...], align: :left}

      iex> MessageInfo.new([ChunkText.new("Hello")], align: :center, padding: 2)
      %MessageInfo{chunks: [...], align: :center, padding: 2}

  """
  @spec new(list(String.t() | ChunkText.t()), keyword()) :: t()
  def new(chunks, opts \\ []) do
    chunks =
      Enum.map(chunks, fn
        %ChunkText{} = chunk -> chunk
        text when is_binary(text) -> ChunkText.new(text)
      end)

    align = Keyword.get(opts, :align, :left)
    align = if align in @valid_aligns, do: align, else: :left

    padding = Keyword.get(opts, :padding, 0)

    add_line = Keyword.get(opts, :add_line, :none)
    add_line = if add_line in @valid_add_lines, do: add_line, else: :none

    raw_coords = Keyword.get(opts, :raw_coords)

    %__MODULE__{
      chunks: chunks,
      align: align,
      padding: padding,
      add_line: add_line,
      raw_coords: raw_coords
    }
  end

  @doc """
  Gets the complete message text (without formatting).

  ## Examples

      iex> msg = MessageInfo.new(["Hello", " world"])
      iex> MessageInfo.get_text(msg)
      "Hello world"

  """
  @spec get_text(t()) :: String.t()
  def get_text(%__MODULE__{chunks: chunks}) do
    Enum.map_join(chunks, "", fn chunk -> chunk.text end)
  end

  @doc """
  Gets the message width (text length without formatting).

  ## Examples

      iex> msg = MessageInfo.new(["Hello world"])
      iex> MessageInfo.get_width(msg)
      11

  """
  @spec get_width(t()) :: integer()
  def get_width(%__MODULE__{} = message_info) do
    message_info |> get_text() |> String.length()
  end

  @doc """
  Normalizes padding to tuple {top, right, bottom, left}.

  ## Examples

      iex> MessageInfo.normalize_padding(2)
      {2, 2, 2, 2}

      iex> MessageInfo.normalize_padding({1, 2, 3, 4})
      {1, 2, 3, 4}

  """
  @spec normalize_padding(padding()) :: {integer(), integer(), integer(), integer()}
  def normalize_padding(padding) when is_integer(padding) do
    {padding, padding, padding, padding}
  end

  def normalize_padding({top, right, bottom, left}) do
    {top, right, bottom, left}
  end
end
