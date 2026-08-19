defmodule Alaja.CLI.ActionError do
  @moduledoc """
  Raised by `alaja action` when the input cannot be processed.

  The CLI entry point (`Alaja.run/2` → `Alaja.CLI.main/1`) catches this
  exception, prints the message to stderr, and exits with status 1.

  Inside a batch (`alaja action --file pipeline.json`), the batch loop
  catches the exception per-action so a single bad action does not
  kill the whole batch.
  """

  defexception [:message]

  @impl true
  def message(%__MODULE__{message: message}), do: message
end
