defmodule SnapshotHelper do
  alias Alaja.Components.{
    Bar,
    Box,
    Breadcrumbs,
    Header,
    Json,
    Separator,
    Table
  }

  @snapshot_dir "test/snapshots"

  def run do
    File.mkdir_p!(@snapshot_dir)

    snapshots = %{
      "separator_default" =>
        Separator.render() |> Alaja.Buffer.to_iodata() |> IO.iodata_to_binary(),
      "separator_with_text" =>
        Separator.render("HELLO", char: "━", color: {0, 180, 216}, width: 40)
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "separator_thin" =>
        Separator.render(nil, char: "─", width: 30)
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "bar_50" =>
        Bar.render(50, 100, label: "CPU", width: 20)
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "bar_75" =>
        Bar.render(75, 100, label: "Upload", width: 40)
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "bar_0" =>
        Bar.render(0, 100, width: 10) |> Alaja.Buffer.to_iodata() |> IO.iodata_to_binary(),
      "bar_100" =>
        Bar.render(100, 100, width: 10) |> Alaja.Buffer.to_iodata() |> IO.iodata_to_binary(),
      "breadcrumbs" =>
        Breadcrumbs.render(["Home", "Projects", "Zaguan"], [])
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "breadcrumbs_short" =>
        Breadcrumbs.render(["A", "B"], [])
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "header_small" =>
        Header.render("Title") |> Alaja.Buffer.to_iodata() |> IO.iodata_to_binary(),
      "header_medium" =>
        Header.render("Title", subtitle: "Subtitle here")
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "header_large" =>
        Header.render("Title", size: :large, color: {255, 87, 51})
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "box_default" =>
        Box.render("Hello, world!", title: "Greeting")
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "box_no_title" =>
        Box.render(["Line 1", "Line 2"], border: :rounded, padding: 2)
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "box_double" =>
        Box.render("Content", border: :double, border_color: {72, 187, 120})
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "json_simple" =>
        Json.render(%{name: "Alaja", version: "0.2.0"})
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      "json_nested" =>
        Json.render(%{deps: ["pote", "jason"], meta: %{author: "Lorenzo", count: 3}})
        |> Alaja.Buffer.to_iodata()
        |> IO.iodata_to_binary(),
      # Table.render() still returns iodata in v0.3.0 (refactor pending)
      "table_simple" =>
        Table.render(
          [
            ["Service", "Status", "Uptime"],
            ["api", "OK", "12d"],
            ["db", "OK", "30d"],
            ["cache", "WARN", "2h"]
          ],
          headers_color: :cyan,
          headers_effects: [:bold],
          rows_2_color: [:white, :yellow, :white],
          table_border: :rounded
        )
        |> IO.iodata_to_binary()
    }

    Enum.each(snapshots, fn {name, content} ->
      path = Path.join(@snapshot_dir, "#{name}.snap")
      File.write!(path, content)
      IO.puts("✓ #{name} (#{byte_size(content)} bytes)")
    end)

    IO.puts("\n#{map_size(snapshots)} snapshots written to #{@snapshot_dir}/")
  end
end

SnapshotHelper.run()
