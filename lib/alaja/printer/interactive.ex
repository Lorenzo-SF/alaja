defmodule Alaja.Printer.Interactive do
  @moduledoc """
  Interactive user-input functions for terminal CLI applications.

  Provides prompts for questions, yes/no confirmation, predefined-option
  selection, and bullet-list menus.

  ## Usage

      answer = Alaja.Printer.Interactive.question("What's your name?")
      :yes  = Alaja.Printer.Interactive.yesno("Continue?")
      Alaja.Printer.Interactive.menu("Select option:", [{"A", :a}, {"B", :b}])
  """

  alias Alaja.Printer
  alias Alaja.Structures.{ChunkText, MessageInfo}
  require Logger

  @doc """
  Asks a question to the user and returns their answer.

  ## Options

  - `:color` - Text color (default: :white)
  - `:align` - Text alignment (default: :left)

  ## Examples

      iex> question("What is your name?")
      "John"

      iex> question("Enter value:", color: :cyan)
      "42"

  """
  @spec question(String.t(), keyword()) :: String.t()
  def question(text, opts \\ []) do
    color = Keyword.get(opts, :color, :white)
    align = Keyword.get(opts, :align, :left)

    chunks = [ChunkText.new(text, color: color)]
    message_info = MessageInfo.new(chunks, align: align)
    Printer.print(message_info)

    case IO.gets("> ") do
      :eof -> ""
      result when is_binary(result) -> String.trim(result)
      _ -> ""
    end
  end

  @doc """
  Question with predefined options.

  Returns the value associated with the selected option,
  or `:error` if the answer doesn't match any option.

  ## Examples

      iex> question_with_options("Choose:", [{"Yes", :yes}, {"No", :no}])
      :yes

  """
  @spec question_with_options(String.t(), list(), keyword()) :: any() | :error
  def question_with_options(text, options, opts \\ []) do
    answer = question(text, opts)

    case Enum.find(options, fn {txt, _} -> txt == answer end) do
      nil -> :error
      {_txt, val} -> val
    end
  end

  @doc """
  Yes or no question.

  Returns `:yes` or `:no`.

  ## Options

  - `:default` - Default answer if user presses Enter (default: :no)

  ## Examples

      iex> yesno("Do you want to continue?")
      :yes

      iex> yesno("Are you sure?", default: :yes)
      :no

  """
  @spec yesno(String.t(), keyword()) :: :yes | :no
  def yesno(text, opts \\ []) do
    default = Keyword.get(opts, :default, :no)

    result =
      question_with_options(text, [{"Y", :yes}, {"y", :yes}, {"N", :no}, {"n", :no}], opts)

    case result do
      :yes -> :yes
      :no -> :no
      :error -> default
      _ -> default
    end
  end

  @doc """
  Shows an options menu.

  Displays a list of options with bullets.

  ## Options

  - `:color` - Text color (default: :white)
  - `:align` - Text alignment (default: :left)
  - `:header` - Optional header text

  ## Examples

      iex> menu("Select an option:", [{"Start", :start}, {"Exit", :exit}])
      :ok

  """
  @spec menu(String.t(), list(), keyword()) :: :ok
  def menu(header_text, options, opts \\ []) do
    color = Keyword.get(opts, :color, :white)
    align = Keyword.get(opts, :align, :left)

    Printer.print(header_text)

    Enum.each(options, fn option ->
      text =
        case option do
          {text, _value} when is_binary(text) -> text
          text when is_binary(text) -> text
          _ -> inspect(option)
        end

      chunks = [ChunkText.new("  • " <> text, color: color)]
      message_info = MessageInfo.new(chunks, align: align)
      Printer.print(message_info)
    end)

    :ok
  end
end
