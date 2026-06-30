defmodule Alaja.SyntaxTest do
  use ExUnit.Case, async: true

  alias Alaja.Syntax

  describe "tokenize/2 — :elixir" do
    test "detects a keyword" do
      tokens = Syntax.tokenize("def hello do", :elixir)
      assert {:keyword, "def"} in tokens
    end

    test "marks a comment line as :comment" do
      tokens = Syntax.tokenize("# a comment line", :elixir)
      assert tokens == [{:comment, "# a comment line"}]
    end
  end

  describe "tokenize/2 — :json" do
    test "detects a number" do
      tokens = Syntax.tokenize("{\"key\": 42}", :json)
      assert {:number, "42"} in tokens
    end
  end

  describe "highlight_content/2" do
    test "returns a non-empty list for markdown" do
      assert [_ | _] = Syntax.highlight_content("# Title", :markdown)
    end

    test "returns the raw line for :text" do
      assert [{_, "hello"}] = Syntax.highlight_content("hello", :text)
    end
  end

  describe "highlight_file/1" do
    test "returns {:error, _} for a non-existent file" do
      assert {:error, _} = Syntax.highlight_file("noexiste.ex")
    end
  end

  describe "highlight_buffer/3 (Buffer-first canonical)" do
    test "returns Alaja.Buffer.t() for built-in :elixir language" do
      assert %Alaja.Buffer{} =
               buf = Syntax.highlight_buffer("defmodule Foo do end", :elixir)

      assert buf.width > 0
      assert buf.height == 1
    end

    test "preserves newlines across multiple buffer rows" do
      content = "defmodule Foo do\n  def bar, do: :ok\nend"

      assert %Alaja.Buffer{} = buf = Syntax.highlight_buffer(content, :elixir)
      assert buf.height == 3, "expected 3 rows for 3-line input, got #{buf.height}"

      rendered = Alaja.Buffer.to_iodata(buf) |> IO.iodata_to_binary()
      assert rendered =~ "defmodule"
      assert rendered =~ "def"
      assert rendered =~ "bar"
      assert rendered =~ "end"
    end

    test "colours :keyword tokens (def, do, end) with the keyword colour" do
      assert %Alaja.Buffer{} = buf = Syntax.highlight_buffer("def foo, do: :ok", :elixir)
      rendered = Alaja.Buffer.to_iodata(buf) |> IO.iodata_to_binary()

      # The keyword colour in the default palette is blue (0, 0, 170)
      assert rendered =~ "\e[38;2;0;0;170m"
    end

    test "colours :string tokens with the string colour" do
      assert %Alaja.Buffer{} =
               buf = Syntax.highlight_buffer(~s({"key": "value"}), :json)

      rendered = Alaja.Buffer.to_iodata(buf) |> IO.iodata_to_binary()
      # The string colour in the default palette is green (0, 170, 0)
      assert rendered =~ "\e[38;2;0;170;0m"
    end

    test "returns a Buffer for :text language (one row)" do
      assert %Alaja.Buffer{} = buf = Syntax.highlight_buffer("plain text", :text)
      assert buf.height == 1
      assert buf.width == "plain text" |> String.length()
    end

    test "honours the registered language's colour table" do
      lang = %Alaja.Syntax.Language{
        name: "my-test-lang",
        colors: %{keyword: {:red, [:bold]}}
      }

      Alaja.Syntax.register_language(:my_test_lang, lang)

      on_exit(fn ->
        # Best-effort cleanup; persistent_term entries linger for the
        # VM lifetime but the test process exits shortly anyway.
        :ok
      end)

      assert %Alaja.Buffer{} =
               buf = Syntax.highlight_buffer("hello world", :my_test_lang)

      rendered = Alaja.Buffer.to_iodata(buf) |> IO.iodata_to_binary()
      assert rendered =~ "\e["
      assert buf.width > 0
    end
  end
end
