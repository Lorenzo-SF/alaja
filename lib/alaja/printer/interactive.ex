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

  The options list can take three shapes:

    1. `[{label, value}, ...]` with string labels — the user types
       the label (or a prefix of it, case-insensitive).
    2. `[{label, value}, ...]` where value is an atom — the user can
       type the atom name (e.g. `:llm` → `llm`).
    3. A 1-based index (`1`, `2`, `3`) typed by the user.

  Before reading the answer, the function lists the options under the
  prompt so the user always knows what they can type. The `:default`
  option chooses a pre-selected index that gets used if the user
  just presses Enter.

  Returns the `value` for the selected option, or `:error` if the
  input does not match anything.

  ## Examples

      iex> question_with_options("Choose:", [{"Yes", :yes}, {"No", :no}])
      :yes

      iex> question_with_options("Continue?", [{\"Y\", :yes}, {\"N\", :no}], default: 1)
      :yes

  """
  @spec question_with_options(String.t(), list(), keyword()) :: any() | :error
  def question_with_options(text, options, opts \\ []) do
    default_index = Keyword.get(opts, :default)
    numbered = options_with_indexes(options)

    prompt =
      [
        text,
        "",
        "  " <> Enum.map_join(numbered, "\n  ", fn {idx, lbl, _} -> "#{idx}. #{lbl}" end)
      ]
      |> Enum.join("\n")

    answer =
      question(
        prompt,
        Keyword.put_new(opts, :color, Keyword.get(opts, :color, :white))
      )

    pick_answer(answer, numbered, default_index)
  end

  # Split [{label, value}] into a list of {1-based-index, label, value}.
  defp options_with_indexes(options) do
    options
    |> Enum.with_index(1)
    |> Enum.map(fn {{label, value}, idx} -> {idx, label, value} end)
  end

  defp pick_answer("", options, default_index) when is_integer(default_index) do
    case Enum.find(options, fn {idx, _, _} -> idx == default_index end) do
      nil -> :error
      {_, _, val} -> val
    end
  end

  defp pick_answer("", _options, _default) do
    # No default and empty input → treat as cancel.
    :error
  end

  defp pick_answer(answer, options, _default) do
    stripped = answer |> String.trim() |> String.downcase()

    with nil <- match_by_index(stripped, options),
         nil <- match_by_label(stripped, options),
         nil <- match_by_prefix(stripped, options),
         nil <- match_by_atom(stripped, options) do
      :error
    end
  end

  defp match_by_index(stripped, options) do
    case Integer.parse(stripped) do
      {n, ""} when n > 0 and n <= length(options) ->
        {_, _, val} = Enum.find(options, fn {i, _, _} -> i == n end)
        val

      _ ->
        nil
    end
  end

  defp match_by_label(stripped, options) do
    case Enum.find(options, fn {_, lbl, _} -> String.downcase(lbl) == stripped end) do
      {_, _, val} -> val
      nil -> nil
    end
  end

  defp match_by_prefix(stripped, options) do
    case Enum.find(options, fn {_, lbl, _} ->
           String.starts_with?(String.downcase(lbl), stripped)
         end) do
      {_, _, val} -> val
      nil -> nil
    end
  end

  defp match_by_atom(stripped, options) do
    case Enum.find(options, fn {_, _, v} -> atom_matches?(v, stripped) end) do
      {_, _, val} -> val
      nil -> nil
    end
  end

  defp atom_matches?(val, stripped) when is_atom(val) do
    String.downcase(Atom.to_string(val)) == stripped
  end

  defp atom_matches?(_val, _stripped), do: false

  @doc """
  Yes or no question.

  Returns `:yes` or `:no`.

  Accepts `y`, `yes`, `n`, `no`, plus the index `1` for yes and `2`
  for no. The `:default` option (`:yes` or `:no`) is used when the
  user just presses Enter.

  ## Examples

      iex> yesno("Do you want to continue?")
      :yes

      iex> yesno("Are you sure?", default: :yes)
      :yes

  """
  @spec yesno(String.t(), keyword()) :: :yes | :no
  def yesno(text, opts \\ []) do
    yes_default = Keyword.get(opts, :default, :no) == :yes

    result =
      question_with_options(
        text,
        if(yes_default,
          do: [{"Y", :yes}, {"N", :no}],
          else: [{"Y", :yes}, {"N", :no}]
        ),
        Keyword.put(opts, :default, if(yes_default, do: 1, else: 2))
      )

    case result do
      :yes -> :yes
      :no -> :no
      :error -> if(yes_default, do: :yes, else: :no)
      _ -> if(yes_default, do: :yes, else: :no)
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
