defmodule Alaja.SubTest do
  use ExUnit.Case, async: true

  alias Alaja.{Msg, Sub}

  test "keypress/0 returns a Keypress" do
    assert %Sub.Keypress{} = Sub.keypress()
  end

  test "tick/1 returns a Tick" do
    assert %Sub.Tick{interval_ms: 500} = Sub.tick(500)
  end

  test "tick/1 rejects non-positive intervals" do
    assert_raise FunctionClauseError, fn -> Sub.tick(0) end
    assert_raise FunctionClauseError, fn -> Sub.tick(-1) end
  end

  test "resize, mouse, paste, focus" do
    assert %Sub.Resize{} = Sub.resize()
    assert %Sub.Mouse{} = Sub.mouse()
    assert %Sub.Paste{} = Sub.paste()
    assert %Sub.Focus{} = Sub.focus()
  end

  test "custom/2" do
    defmodule MySub do
      def attach(_opts, app), do: {:ok, spawn_link(fn -> send(app, :attached) end)}
      def detach(pid, _opts), do: Process.exit(pid, :kill)
    end

    sub = Sub.custom(MySub, [])
    assert {:ok, pid} = Sub.attach(sub, self())
    assert is_pid(pid)
    assert_receive :attached, 500
    assert :ok = Sub.detach(sub, pid)
  end

  test "custom sub missing attach returns error" do
    defmodule BadSub do
      # no attach/2
    end

    sub = Sub.custom(BadSub, [])
    assert {:error, {:missing_attach, BadSub}} = Sub.attach(sub, self())
  end

  test "tick sub emits Msg.Tick periodically" do
    {:ok, pid} = Sub.attach(Sub.tick(20), self())
    # Tick uses Alaja.App.update → GenServer.cast
    assert_receive {:"$gen_cast", {:msg, %Msg.Tick{}}}, 500
    assert :ok = Sub.detach(Sub.tick(20), pid)
  end

  test "detach is idempotent on nil pid for Tick" do
    assert :ok = Sub.detach(Sub.tick(100), nil)
  end
end
