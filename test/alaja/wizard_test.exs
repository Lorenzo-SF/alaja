defmodule Alaja.WizardTest do
  use ExUnit.Case

  alias Alaja.{Buffer, Wizard}

  defp sample_wizard do
    Wizard.new(title: "Profile")
    |> Wizard.field(:name, :string, label: "Name", default: "alice")
    |> Wizard.field(:age, :integer, label: "Age", default: 30)
    |> Wizard.field(:newsletter, :boolean, label: "Subscribe", default: true)
  end

  describe "new/1 + field/3" do
    test "builds an empty wizard with the requested options" do
      w = Wizard.new(title: "T", renderer: :stacked)
      assert %Wizard{} = w
      assert w.title == "T"
      assert w.renderer == :stacked
      assert w.fields == []
    end

    test "appends fields with the given type and options" do
      w =
        Wizard.new()
        |> Wizard.field(:name, :string, label: "Name", default: "alice")

      assert [%{name: :name, label: "Name", type: :string, default: "alice", value: "alice"}] =
               w.fields
    end

    test "humanises the label when none is given" do
      w = Wizard.new() |> Wizard.field(:first_name, :string)
      assert hd(w.fields).label == "First name"
    end

    test "preserves the field insertion order" do
      w =
        Wizard.new()
        |> Wizard.field(:a, :string)
        |> Wizard.field(:b, :integer)
        |> Wizard.field(:c, :boolean)

      assert Enum.map(w.fields, & &1.name) == [:a, :b, :c]
    end
  end

  describe "set/3" do
    test "updates the value of an existing field" do
      w = sample_wizard() |> Wizard.set(:age, 31)
      assert hd(tl(w.fields)).value == 31
    end

    test "raises ArgumentError for an unknown field" do
      assert_raise ArgumentError, ~r/no field named :nope/, fn ->
        Wizard.set(sample_wizard(), :nope, "anything")
      end
    end
  end

  describe "render/2 dispatcher" do
    test "falls back to the wizard's :renderer option when no renderer is given" do
      w = Wizard.new(renderer: :inline) |> Wizard.field(:a, :string, default: "x")
      assert %Buffer{} = Wizard.render(w)
    end

    test "raises ArgumentError on an unknown renderer" do
      assert_raise ArgumentError, ~r/Unknown Wizard renderer/, fn ->
        Wizard.render(sample_wizard(), :bogus)
      end
    end
  end

  describe "renderers" do
    test "all five renderers return an Alaja.Buffer.t/0" do
      w = sample_wizard()

      for renderer <- [:inline, :compact, :stacked, :wizard, :compact_wizard] do
        assert %Buffer{} = buf = Wizard.render(w, renderer)
        assert buf.width > 0
        assert buf.height > 0
      end
    end

    test ":inline produces a single-line buffer" do
      w = sample_wizard()
      assert %Buffer{height: 1} = Wizard.render(w, :inline)
    end

    test ":compact aligns labels in two columns" do
      w =
        Wizard.new()
        |> Wizard.field(:name, :string, default: "alice")
        |> Wizard.field(:age, :integer, default: 30)

      rendered = Wizard.render(w, :compact) |> Buffer.to_iodata() |> IO.iodata_to_binary()
      assert rendered =~ "alice"
      assert rendered =~ "30"
    end

    test ":stacked puts each label above its value" do
      w =
        Wizard.new()
        |> Wizard.field(:name, :string, default: "alice")

      rendered = Wizard.render(w, :stacked) |> Buffer.to_iodata() |> IO.iodata_to_binary()
      assert rendered =~ "alice"
      assert rendered =~ "Name"
    end

    test ":wizard uses a box border and includes the title" do
      w = Wizard.new(title: "My Profile") |> Wizard.field(:name, :string, default: "alice")
      rendered = Wizard.render(w, :wizard) |> Buffer.to_iodata() |> IO.iodata_to_binary()
      assert rendered =~ "My Profile"
      assert rendered =~ "┌"
      assert rendered =~ "└"
    end

    test ":compact_wizard produces a single body line inside a box" do
      w = Wizard.new(title: "Mini") |> Wizard.field(:name, :string, default: "alice")
      rendered = Wizard.render(w, :compact_wizard) |> Buffer.to_iodata() |> IO.iodata_to_binary()
      assert rendered =~ "Mini"
      assert rendered =~ "alice"
      # One body row between top and bottom borders
      lines = String.split(rendered, "\n")
      assert length(lines) == 3
    end

    test "renderers are pure — same input produces equal output" do
      w = sample_wizard()

      buf1 = Wizard.render(w, :compact)
      buf2 = Wizard.render(w, :compact)

      assert buf1.width == buf2.width
      assert buf1.height == buf2.height

      # Same chars in the same positions
      for y <- 0..(buf1.height - 1),
          x <- 0..(buf1.width - 1) do
        assert Buffer.get(buf1, x, y).char == Buffer.get(buf2, x, y).char
      end
    end

    test ":boolean renders as [x] / [ ] in :inline" do
      w =
        Wizard.new()
        |> Wizard.field(:on, :boolean, default: true)
        |> Wizard.field(:off, :boolean, default: false)

      rendered = Wizard.render(w, :inline) |> Buffer.to_iodata() |> IO.iodata_to_binary()
      assert rendered =~ "[x]"
      assert rendered =~ "[ ]"
    end
  end
end
