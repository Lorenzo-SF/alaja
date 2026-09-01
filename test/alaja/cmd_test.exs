defmodule Alaja.CmdTest do
  use ExUnit.Case, async: true

  alias Alaja.Cmd
  alias Alaja.Msg

  test "none/0 returns a None" do
    assert %Cmd.None{} = Cmd.none()
  end

  test "log/1 returns a Log" do
    assert %Cmd.Log{message: "hello"} = Cmd.log("hello")
  end

  test "quit/0 returns a Quit" do
    assert %Cmd.Quit{} = Cmd.quit()
  end

  test "batch/1 returns a Batch" do
    assert %Cmd.Batch{cmds: []} = Cmd.batch([])
    assert %Cmd.Batch{cmds: [%Cmd.None{}]} = Cmd.batch([Cmd.none()])
  end

  test "send_msg/2 with pid sends a cast" do
    test_pid = self()

    cmd = Cmd.send_msg(test_pid, Msg.key("a"))
    assert :ok = Cmd.run(cmd, self())

    # verify the cast arrived (Cmd.send_msg → Alaja.App.update → GenServer.cast)
    assert_receive {:"$gen_cast", {:msg, msg}}, 500
    assert msg.key == "a"
  end

  test "send_msg/2 with named atom" do
    # When target is a name, GenServer.cast expects a registered name.
    # Use an atom that doesn't exist; the cast returns :ok even if no
    # process is registered.
    cmd = Cmd.send_msg(:non_existent_name_1234, Msg.tick())
    assert :ok = Cmd.run(cmd, self())
  end

  test "quit sends Msg.Quit to the app" do
    test_pid = self()

    cmd = Cmd.quit()
    assert :ok = Cmd.run(cmd, test_pid)

    assert_receive {:"$gen_cast", {:msg, %Msg.Quit{}}}, 500
  end

  test "log writes to stderr" do
    output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        cmd = Cmd.log("test log")
        assert :ok = Cmd.run(cmd, self())
      end)

    assert output =~ "test log"
  end

  test "batch runs all commands" do
    test_pid = self()
    cmd = Cmd.batch([Cmd.send_msg(test_pid, Msg.key("a")), Cmd.send_msg(test_pid, Msg.key("b"))])
    assert :ok = Cmd.run(cmd, self())

    assert_receive {:"$gen_cast", {:msg, %{key: "a"}}}, 500
    assert_receive {:"$gen_cast", {:msg, %{key: "b"}}}, 500
  end

  test "unknown command returns error" do
    assert {:error, {:unknown_cmd, :foo}} = Cmd.run(:foo, self())
  end

  test "custom/2 wraps a module + data" do
    defmodule TestCmd do
      def run(:payload, _app), do: :ok
    end

    assert %Cmd.Custom{mod: TestCmd, data: :payload} = Cmd.custom(TestCmd, :payload)
    assert :ok = Cmd.run(Cmd.custom(TestCmd, :payload), self())
  end
end
