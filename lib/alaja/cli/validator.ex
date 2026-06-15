defmodule Alaja.CLI.Validator do
  @moduledoc """
  Validacion de inputs para comandos CLI.

  ## Uso

      Alaja.CLI.Validator.validate_flags(flags, parsed)
      Alaja.CLI.Validator.validate_args(arguments, positional)
  """

  @dangerous_patterns [
    ~r/rm\s+-rf\s+\//,
    ~r/sudo\s+rm/,
    ~r/dd\s+if=/,
    ~r/mkfs\./,
    ~r/:\(\)\s*\{/,
    ~r/>\/dev\/sda/,
    ~r/chmod\s+777/,
    ~r/wget.*\|\s*sh/,
    ~r/curl.*\|\s*bash/
  ]

  @doc "Validates parsed flags against command definition."
  @spec validate_flags([map()], keyword()) :: :ok | {:error, [String.t()]}
  def validate_flags(flags, parsed) do
    errors =
      Enum.flat_map(flags, fn flag ->
        value = Keyword.get(parsed, flag.name, flag.default)
        validate_flag(flag, value)
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  defp validate_flag(flag, nil) do
    if flag.required, do: ["--#{flag.name} is required"], else: []
  end

  defp validate_flag(flag, value) do
    errors = []

    errors =
      if flag.values && value not in flag.values do
        errors ++
          ["--#{flag.name}: '#{value}' is not valid. Allowed: #{Enum.join(flag.values, ", ")}"]
      else
        errors
      end

    errors ++ validate_flag_type(flag, value)
  end

  defp validate_flag_type(flag, value) do
    case flag.type do
      :integer ->
        case Integer.parse(to_string(value)) do
          {_, ""} -> []
          _ -> ["--#{flag.name}: expected integer, got '#{value}'"]
        end

      :float ->
        case Float.parse(to_string(value)) do
          {_, ""} -> []
          _ -> ["--#{flag.name}: expected float, got '#{value}'"]
        end

      _ ->
        []
    end
  end

  @doc "Validates positional arguments against command definition."
  @spec validate_args([map()], [String.t()]) :: :ok | {:error, [String.t()]}
  def validate_args(arguments, positional) do
    required = Enum.filter(arguments, & &1.required)

    if length(positional) < length(required) do
      missing = Enum.drop(required, length(positional))
      {:error, Enum.map(missing, fn a -> "Missing required argument: #{a.name}" end)}
    else
      :ok
    end
  end

  @doc "Checks if a command is potentially dangerous."
  @spec dangerous?(String.t()) :: boolean()
  def dangerous?(command) do
    Enum.any?(@dangerous_patterns, &Regex.match?(&1, command))
  end
end
