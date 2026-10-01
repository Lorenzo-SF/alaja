defmodule Alaja.CLI.Exit do
  @moduledoc """
  Excepción que termina el CLI con un código de salida concreto.

  `Alaja.CLI.ActionError` siempre sale con 1. Un host que necesita
  códigos distintos por tipo de fallo (por ejemplo, Acho, que
  distingue 10 variable-no-resuelta de 20 error-de-red) lanza esta
  excepción y el entry point imprime el mensaje y sale con `:exit_code`.

      raise Alaja.CLI.Exit, message: "env 'prod' no encontrado", exit_code: 11

  El entry point generado por `Alaja.CLI.Definition` la rescuea, escribe
  el mensaje en stderr y hace `exit({:shutdown, exit_code})`.
  """

  defexception [:message, :exit_code]

  @type t :: %__MODULE__{message: String.t(), exit_code: non_neg_integer()}

  @impl true
  @spec message(t()) :: String.t()
  def message(%__MODULE__{message: message}), do: message

  @doc "Construye la excepción con keyword list."
  @spec new(String.t(), non_neg_integer()) :: t()
  def new(message, exit_code) when is_binary(message) and is_integer(exit_code) do
    %__MODULE__{message: message, exit_code: exit_code}
  end
end
