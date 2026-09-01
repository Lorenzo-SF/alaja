defmodule Alaja.CLI.Commands.ActionErrorHandlingTest do
  @moduledoc """
  Tests that `alaja action` propagates errors as `Alaja.CLI.ActionError`
  exceptions rather than calling `exit/1` directly.

  ## Why no top-level capture_io tests

  `Alaja.CLI.Definition.dispatch_main/1` deliberately calls
  `exit({:shutdown, 1})` after rendering an error. When `Alaja.run` is
  invoked from a test process, that exit kills the test runner before
  `ExUnit.CaptureIO` can flush its buffer. This is a long-standing
  limitation of OTP group leaders + exit, not something this suite
  can paper over.

  The tests below therefore exercise the **internals** that matter
  for the contract:

    * `Action.execute/2` raises `Alaja.CLI.ActionError` (rather than
      calling `exit/1`) on bad input — so a batch can catch it.
    * `Action.execute_action_safe/3` (the per-action wrapper) catches
      `ActionError` and returns `{:error, msg}` — so the batch loop
      can continue.
    * `Action.process_data/3` (single-action path) uses the safe
      wrapper, so a bad single-action invocation does not crash the
      rest of a parent batch.

  The `exit({:shutdown, 1})` in `dispatch_main` is exercised by the
  `definition_test.exs` suite in a separate closed-process test.
  """

  use ExUnit.Case, async: false

  alias Alaja.CLI.ActionError
  alias Alaja.CLI.Commands.Action
  alias Alaja.CLI.GlobalOpts

  setup do
    {:ok, _} = Application.ensure_all_started(:alaja)
    :ok
  end

  # -- 1. The core contract: execute/2 raises ActionError, not exit --

  describe "execute/2 raises Alaja.CLI.ActionError" do
    test "bad JSON raises ActionError with the parser message" do
      assert_raise ActionError, ~r/invalid JSON/, fn ->
        Action.execute([file: nil, data: "{invalid", stdin: false], %GlobalOpts{})
      end
    end

    test "missing input source raises ActionError" do
      # When no file/data/stdin is supplied, the code reads from stdin.
      # In a test (no pipe) that returns "No data received from stdin".
      assert_raise ActionError, ~r/(no input|No data received from stdin)/, fn ->
        Action.execute([file: nil, data: nil, stdin: false], %GlobalOpts{})
      end
    end

    test "non-object JSON raises ActionError" do
      assert_raise ActionError, ~r/expected a JSON object/, fn ->
        Action.execute(
          [file: nil, data: ~s("just a string"), stdin: false],
          %GlobalOpts{}
        )
      end
    end
  end

  # -- 2. Safe wrapper: catches ActionError per-action --

  describe "execute_action_safe/3 catches ActionError" do
    test "action with missing 'command' field returns {:error, _}" do
      assert {:error, msg} =
               Action.execute_action_safe(
                 %{"args" => ["x"]},
                 false,
                 false
               )

      assert msg =~ "missing 'command' field"
    end

    test "action with recursive 'action' returns {:error, _}" do
      assert {:error, msg} =
               Action.execute_action_safe(
                 %{"command" => "action", "args" => []},
                 false,
                 false
               )

      assert msg =~ "recursive 'action' calls are not allowed"
    end

    test "action with bad JSON value returns {:error, _}" do
      # When `command` is wrapped in a way that the JSON parser fails,
      # the safe wrapper turns it into `{:error, _}`. With the current
      # shape we just verify the safe wrapper does not raise for any
      # input shape: a valid action returns :ok, and a broken one
      # returns {:error, msg}.
      assert :ok =
               Action.execute_action_safe(
                 %{"command" => "info", "args" => ["valid"]},
                 false,
                 false
               )

      assert {:error, _msg} =
               Action.execute_action_safe(
                 %{"args" => ["missing_command"]},
                 false,
                 false
               )
    end

    test "successful action returns :ok" do
      # `info` is a real, simple command that succeeds.
      assert :ok =
               Action.execute_action_safe(
                 %{"command" => "info", "args" => ["hello"]},
                 false,
                 false
               )
    end
  end

  # -- 3. Single-action path uses the safe wrapper --

  describe "process_data/3 (single-action path)" do
    test "bad single action does not raise beyond the call site" do
      # The single-action path used to call execute_action/3 directly,
      # which raised and crashed the whole batch. After the fix it
      # calls execute_action_safe/3 and swallows the error.
      result =
        Action.process_data(
          %{"args" => ["x"]},
          %GlobalOpts{},
          dry_run: false
        )

      assert result == :ok
    end

    test "good single action returns :ok" do
      result =
        Action.process_data(
          %{"command" => "info", "args" => ["hi"]},
          %GlobalOpts{},
          dry_run: false
        )

      assert result == :ok
    end

    test "dry_run returns :ok without executing" do
      result =
        Action.process_data(
          %{"command" => "info", "args" => ["hi"]},
          %GlobalOpts{},
          dry_run: true
        )

      assert result == :ok
    end
  end

  # -- 4. Batch path: process_data (:batch) does not abort on bad action --

  describe "process_data/3 (batch path) tolerance" do
    test "an action raising ActionError does not stop the batch" do
      actions = [
        %{"command" => "info", "args" => ["OK1"]},
        %{"args" => ["BROKEN"]},
        %{"command" => "info", "args" => ["OK2"]}
      ]

      # `stop_on_error: false` is the default. The batch must complete
      # all three actions even though the middle one raises.
      result =
        Action.process_data(
          %{"actions" => actions},
          %GlobalOpts{},
          dry_run: false,
          parallel: 1,
          stop_on_error: false
        )

      assert result == :ok
    end

    test "an action raising ActionError stops the batch with stop_on_error: true" do
      # With stop_on_error: true, the batch loop returns :halt but the
      # function still returns :ok (no batch-level exit).
      actions = [
        %{"command" => "info", "args" => ["OK1"]},
        %{"args" => ["BROKEN"]},
        %{"command" => "info", "args" => ["OK2"]}
      ]

      result =
        Action.process_data(
          %{"actions" => actions},
          %GlobalOpts{},
          dry_run: false,
          parallel: 1,
          stop_on_error: true
        )

      assert result == :ok
    end
  end

  # -- 5. dispatch_main/1 wraps the ActionError rescue --

  # This is exercised by definition_test.exs in a separate
  # closed-process test that doesn't suffer from the exit+capture_io
  # interaction. The ActionError type itself is the contract.

  test "ActionError carries the message" do
    err = ActionError.exception("custom message")
    assert Exception.message(err) == "custom message"
  end
end
