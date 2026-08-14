defmodule Alaja.CLI.GlobalOptsTest do
  use ExUnit.Case

  alias Alaja.CLI.GlobalOpts

  describe "parse/1" do
    test "returns defaults for empty args" do
      {opts, rest} = GlobalOpts.parse([])
      assert opts.help == false
      assert opts.raw == false
      assert opts.verbose == false
      assert opts.box == false
      assert opts.quiet == false
      assert opts.stdin == false
      assert rest == []
    end

    test "parses --help flag" do
      {opts, _rest} = GlobalOpts.parse(["--help"])
      assert opts.help == true
    end

    test "parses -h shorthand" do
      {opts, _rest} = GlobalOpts.parse(["-h"])
      assert opts.help == true
    end

    test "parses --raw flag" do
      {opts, _rest} = GlobalOpts.parse(["--raw"])
      assert opts.raw == true
    end

    test "parses --verbose flag" do
      {opts, _rest} = GlobalOpts.parse(["--verbose"])
      assert opts.verbose == true
    end

    test "parses --pos-x and --pos-y" do
      {opts, _rest} = GlobalOpts.parse(["--pos-x", "10", "--pos-y", "5"])
      assert opts.pos_x == 10
      assert opts.pos_y == 5
    end

    test "parses --align" do
      {opts, _rest} = GlobalOpts.parse(["--align", "center"])
      assert opts.align == :center
    end

    test "parses --box flag" do
      {opts, _rest} = GlobalOpts.parse(["--box"])
      assert opts.box == true
    end

    test "parses --box-title" do
      {opts, _rest} = GlobalOpts.parse(["--box", "--box-title", "My Box"])
      assert opts.box == true
      assert opts.box_title == "My Box"
    end

    test "parses --box-border" do
      {opts, _rest} = GlobalOpts.parse(["--box", "--box-border", "double"])
      assert opts.box == true
      assert opts.box_border == :double
    end

    test "parses --quiet flag" do
      {opts, _rest} = GlobalOpts.parse(["--quiet"])
      assert opts.quiet == true
    end

    test "parses --stdin flag" do
      {opts, _rest} = GlobalOpts.parse(["--stdin"])
      assert opts.stdin == true
    end

    test "parses --no-color flag" do
      {opts, _rest} = GlobalOpts.parse(["--no-color"])
      assert opts.no_color == true
      assert opts.color == false
    end

    test "parses --color flag (force)" do
      {opts, _rest} = GlobalOpts.parse(["--color"])
      assert opts.color == true
      assert opts.no_color == false
    end

    test "--no-color and --color both set (last wins on no_color side)" do
      {opts, _rest} = GlobalOpts.parse(["--no-color", "--color"])
      assert opts.color == true
      assert opts.no_color == true
    end

    test "leaves unknown args in rest" do
      {_opts, rest} = GlobalOpts.parse(["--unknown", "value"])
      assert rest == ["--unknown", "value"]
    end

    test "leaves positional args in rest" do
      {_opts, rest} = GlobalOpts.parse(["positional", "arg"])
      assert rest == ["positional", "arg"]
    end
  end

  describe "to_printer_opts/1" do
    test "converts global opts to keyword list" do
      {opts, _} = GlobalOpts.parse(["--raw", "--pos-x", "5", "--verbose", "--align", "center"])
      kw = GlobalOpts.to_printer_opts(opts)
      assert kw[:raw] == true
      assert kw[:pos_x] == 5
      assert kw[:verbose] == true
      assert kw[:align] == :center
    end

    test "passes no_color/color through to printer opts" do
      {opts, _} = GlobalOpts.parse(["--no-color"])
      kw = GlobalOpts.to_printer_opts(opts)
      assert kw[:no_color] == true
      assert kw[:color] == false
    end

    test "passes bg_color through to printer opts" do
      {opts, _} = GlobalOpts.parse(["--bg-color", "hex:333333"])
      kw = GlobalOpts.to_printer_opts(opts)
      assert kw[:bg_color] == {51, 51, 51}
    end
  end

  describe "parse/1 --bg-color" do
    test "parses explicit format" do
      {opts, _rest} = GlobalOpts.parse(["--bg-color", "rgb:51;51;51"])
      assert opts.bg_color == {51, 51, 51}
    end

    test "parses #hex via autodetection" do
      {opts, _rest} = GlobalOpts.parse(["--bg-color", "#333333"])
      assert opts.bg_color == {51, 51, 51}
    end

    test "invalid color leaves bg_color nil" do
      {opts, _rest} = GlobalOpts.parse(["--bg-color", "gibberish"])
      assert opts.bg_color == nil
    end

    test "defaults to nil without flag" do
      {opts, _rest} = GlobalOpts.parse([])
      assert opts.bg_color == nil
    end
  end
end
