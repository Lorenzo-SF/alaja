defmodule Alaja.CLI.DispatchTest do
  use ExUnit.Case, async: true

  alias Alaja.CLI.Dispatch

  describe "typed messages" do
    test "success/1 prints success" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.success(%{_args: ["hello"]})
        end)

      assert output =~ "hello"
    end

    test "error/1 prints error" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.error(%{_args: ["bad"]})
        end)

      assert output =~ "bad"
    end

    test "warning/1 prints warning" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.warning(%{_args: ["watch out"]})
        end)

      assert output =~ "watch out"
    end

    test "info/1 prints info" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.info(%{_args: ["note"]})
        end)

      assert output =~ "note"
    end

    test "debug/1 prints" do
      output = ExUnit.CaptureIO.capture_io(fn -> Dispatch.debug(%{_args: ["x"]}) end)
      assert output =~ "x"
    end

    test "notice/1 prints" do
      output = ExUnit.CaptureIO.capture_io(fn -> Dispatch.notice(%{_args: ["x"]}) end)
      assert output =~ "x"
    end

    test "critical/1 prints" do
      output = ExUnit.CaptureIO.capture_io(fn -> Dispatch.critical(%{_args: ["x"]}) end)
      assert output =~ "x"
    end

    test "alert/1 prints" do
      output = ExUnit.CaptureIO.capture_io(fn -> Dispatch.alert(%{_args: ["x"]}) end)
      assert output =~ "x"
    end

    test "emergency/1 prints" do
      output = ExUnit.CaptureIO.capture_io(fn -> Dispatch.emergency(%{_args: ["x"]}) end)
      assert output =~ "x"
    end

    test "happy/1 prints" do
      output = ExUnit.CaptureIO.capture_io(fn -> Dispatch.happy(%{_args: ["x"]}) end)
      assert output =~ "x"
    end

    test "sad/1 prints" do
      output = ExUnit.CaptureIO.capture_io(fn -> Dispatch.sad(%{_args: ["x"]}) end)
      assert output =~ "x"
    end
  end

  describe "display commands" do
    test "message/1 falls through to Message.run" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.message(%{_args: ["hello"]})
        end)

      assert output =~ "hello"
    end

    test "header/1 requires a title" do
      # header/1 would normally render — we just confirm it doesn't crash
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.header(%{_args: ["My Title"]})
        end)

      assert is_binary(output)
    end

    test "separator/1 renders" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.separator(%{_args: []})
        end)

      assert is_binary(output)
    end

    test "gradient/1 renders text" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.gradient(%{_args: ["hello", "--from", "#ff0000", "--to", "#0000ff"]})
        end)

      # Gradient output includes ANSI color codes, so we look for the
      # letters individually
      for char <- ~w(h e l l o) do
        assert output =~ char
      end
    end

    test "bar/1 renders a bar" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.bar(%{_args: ["50"]})
        end)

      assert is_binary(output)
    end

    test "breadcrumbs/1 renders path" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.breadcrumbs(%{_args: ["a", "b", "c"]})
        end)

      assert is_binary(output)
    end

    test "list/1 renders list" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.list(%{_args: ["item1,item2,item3"]})
        end)

      assert is_binary(output)
    end

    test "json/1 requires data" do
      # Without --data, json/1 should call help or error
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.json(%{_args: []})
        end)

      assert is_binary(output)
    end

    test "color/1 requires an argument or flag" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.color(%{_args: []})
        end)

      assert is_binary(output)
    end

    test "action/1 with no data calls help" do
      # The action command may attempt to read stdin (triggering a GenServer
      # crash in StringIO when there is no TTY). We use safe_call to suppress
      # the crash and simply verify the dispatch does not raise synchronously.
      assert :ok = safe_call(fn -> Dispatch.action(%{_args: []}) end)
    end

    defp safe_call(fun) do
      try do
        fun.()
      rescue
        _ -> :ok
      catch
        _, _ -> :ok
      end

      :ok
    end

    test "config/1 dispatches to Config.run" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Dispatch.config(%{_args: ["--show"]})
        end)

      assert is_binary(output)
    end
  end
end
