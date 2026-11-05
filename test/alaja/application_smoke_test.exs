defmodule Alaja.ApplicationSmokeTest do
  use ExUnit.Case, async: false

  # Smoke test: verify the application supervisor started without errors.
  # alaja.Application deliberately has no children (backends are spawned
  # on-demand), but the supervisor process must exist.

  test "Alaja.Supervisor is started" do
    assert Process.whereis(Alaja.Supervisor) != nil
  end

  test "Alaja.Config is loaded" do
    # Application.start/2 calls Config.ensure_loaded/0.  This must not
    # raise.
    assert :ok = Alaja.Config.ensure_loaded()
  end

  test "Alaja.Theme is registered with Pote" do
    # Application.start/2 calls Theme.register_with_pote/0.  Verify the
    # theme lookup function is callable.
    assert is_function(Alaja.Theme.resolve_with_pote(), 0) or
             is_function(Alaja.Theme.resolve_with_pote(), 1)
  end
end
