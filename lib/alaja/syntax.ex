defmodule Alaja.Syntax do
  @moduledoc """
  Syntax highlighting for terminal output.

  Supported languages: `:elixir`, `:json`, `:markdown`, `:text`.
  """

  @type language :: :elixir | :json | :markdown | :text
  @type token :: {atom(), String.t()}

  # Elixir keywords
  @elixir_keywords ~w(def defmodule defp do end case cond if else when with fn
                       use import alias require receive send raise try catch
                       after rescue throw for while return)

  @doc """
  Highlights a file by detecting language from extension and printing to stdout.

  Returns `{:ok, cells}` where cells is a list of `{color, text}` tuples,
  or `{:error, reason}` if the file cannot be read.
  """
  @spec highlight_file(String.t()) :: {:ok, list()} | {:error, String.t()}
  def highlight_file(path) do
    case File.read(path) do
      {:ok, content} ->
        lang = detect_language(path)
        {:ok, highlight_content(content, lang)}

      {:error, reason} ->
        {:error, "cannot read file: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Highlights content string for a given language.

  Returns a list of `{color, text}` tuples suitable for terminal rendering.
  """
  @spec highlight_content(String.t(), language()) :: list()
  def highlight_content(content, language) do
    content
    |> String.split("\n")
    |> Enum.flat_map(&highlight_line(&1, language))
  end

  @doc """
  Tokenizes a single line of code into `{token_type, text}` tuples.

  Token types: `:keyword`, `:string`, `:comment`, `:number`, `:operator`,
  `:atom`, `:module`, `:plain`.
  """
  @spec tokenize(String.t(), language()) :: [token()]
  def tokenize(line, language) do
    case language do
      :elixir -> tokenize_elixir(line)
      :json -> tokenize_json(line)
      :markdown -> tokenize_markdown(line)
      :text -> [{:plain, line}]
    end
  end

  # --- Language detection ---

  defp detect_language(path) do
    case Path.extname(path) do
      ".ex" -> :elixir
      ".exs" -> :elixir
      ".json" -> :json
      ".md" -> :markdown
      _ -> :text
    end
  end

  # --- High-level highlighting ---

  defp highlight_line(line, language) do
    line
    |> tokenize(language)
    |> Enum.map(fn {type, text} -> {color_for(type), text} end)
  end

  defp color_for(:keyword), do: "blue"
  defp color_for(:string), do: "green"
  defp color_for(:comment), do: "gray"
  defp color_for(:number), do: "cyan"
  defp color_for(:operator), do: "white"
  defp color_for(:atom), do: "yellow"
  defp color_for(:module), do: "magenta"
  defp color_for(:plain), do: "white"
  defp color_for(_), do: "white"

  # --- Elixir tokenizer ---

  defp tokenize_elixir(line) do
    if String.starts_with?(String.trim_leading(line), "#") do
      [{:comment, line}]
    else
      tokenize_elixir_parts(line, [])
    end
  end

  defp tokenize_elixir_parts("", acc), do: Enum.reverse(acc)

  defp tokenize_elixir_parts(line, acc) do
    {token, rest} = take_next_token(line)

    {type, text} =
      case token do
        "" -> {:plain, rest}
        text -> classify_token(text)
      end

    if rest == "" or rest == line do
      Enum.reverse([{type, text} | acc])
    else
      tokenize_elixir_parts(rest, [{type, text} | acc])
    end
  end

  defp classify_token(text) do
    cond do
      String.starts_with?(text, "\"") -> {:string, text}
      atom_token?(text) -> {:atom, text}
      String.starts_with?(text, "#") -> {:comment, text}
      text in @elixir_keywords -> {:keyword, text}
      module_token?(text) -> {:module, text}
      number_token?(text) -> {:number, text}
      true -> {:plain, text}
    end
  end

  defp atom_token?(text),
    do: String.starts_with?(text, ":") and not String.starts_with?(text, "::")

  defp module_token?(text), do: Regex.match?(~r/^[A-Z]/, text) and String.contains?(text, ".")
  defp number_token?(text), do: Regex.match?(~r/^-?\d+(\.\d+)?$/, text)

  defp take_next_token(line) do
    case Regex.run(
           ~r/^(\s+|[A-Za-z_][A-Za-z0-9_]*[!?]?|"[^"]*"|:[A-Za-z_][A-Za-z0-9_]*[!?]?|#[^\n]*|-?\d+(\.\d+)?|.)/,
           line
         ) do
      [match, token] -> {token, String.replace_prefix(line, match, "")}
      _ -> {"", line}
    end
  end

  # --- JSON tokenizer ---

  defp tokenize_json(line) do
    line
    |> String.split(~r/("[^"]*"|\d+|true|false|null|[{}\[\],:])/,
      include_captures: true,
      trim: true
    )
    |> Enum.map(fn token ->
      cond do
        String.starts_with?(token, "\"") -> {:string, token}
        token in ["true", "false", "null"] -> {:keyword, token}
        token in ["{", "}", "[", "]", ",", ":"] -> {:operator, token}
        Regex.match?(~r/^\d+(\.\d+)?$/, token) -> {:number, token}
        true -> {:plain, token}
      end
    end)
  end

  # --- Markdown tokenizer ---

  defp tokenize_markdown(line) do
    cond do
      Regex.match?(~r/^\#{1,6}\s+/, line) -> [{:keyword, line}]
      Regex.match?(~r/^\*\*[^*]+\*\*$/, String.trim(line)) -> [{:keyword, line}]
      Regex.match?(~r/^\*[^*]+\*$/, String.trim(line)) -> [{:keyword, line}]
      String.contains?(line, "`") -> [{:string, line}]
      String.contains?(line, "](") -> [{:module, line}]
      true -> [{:plain, line}]
    end
  end
end
