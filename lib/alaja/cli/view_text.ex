defmodule Alaja.CLI.ViewText do
  @moduledoc """
  Converts a `Alaja.View.Node` tree into plain or ANSI text for CLI output.

  The component views (`Alaja.Components.list_view/1`, `tabs_view/1`, ...)
  return view trees that the interactive runtime renders through
  `Alaja.Layout.render_to_frame/3`. The CLI instead flattens the tree to a
  string, mirroring the layout semantics (`column` joins rows with newlines,
  `row` joins children with spaces) and applying text styles as ANSI effects.
  """

  alias Alaja.View.Node

  @doc "Renders a view node tree to a string. Styles become ANSI escapes unless `ansi: false`."
  @spec render(Node.t() | nil, keyword()) :: String.t()
  def render(node), do: render(node, [])

  def render(nil, _opts), do: ""

  def render(%Node{tag: :text, props: props}, opts) do
    content = Keyword.get(props, :content, "")

    if Keyword.get(opts, :ansi, true) do
      apply_style(content, Keyword.get(props, :style, []))
    else
      content
    end
  end

  def render(%Node{tag: :rule}, _opts), do: "─"

  def render(%Node{tag: :column, children: children, props: props}, opts) do
    pad = Keyword.get(props, :padding, 0)
    gap = Keyword.get(props, :gap, 0)
    join_children(children, "\n", pad, gap, opts)
  end

  def render(%Node{tag: :row, children: children, props: props}, opts) do
    pad = Keyword.get(props, :padding, 0)
    gap = Keyword.get(props, :gap, 0)
    join_children(children, " ", pad, gap, opts)
  end

  def render(%Node{}, _opts), do: ""

  defp join_children(children, join, pad, gap, opts) do
    separator = String.duplicate(join, max(gap, 0))
    indent = String.duplicate(" ", pad)

    parts =
      Enum.map(children, fn child ->
        if join == "\n" do
          [indent, render(child, opts)]
        else
          render(child, opts)
        end
      end)

    parts
    |> Enum.intersperse(separator)
    |> IO.iodata_to_binary()
  end

  defp apply_style(content, style) do
    case Enum.map(style, &effect_to_ansi/1) do
      [] -> content
      prefixes -> [prefixes, content, IO.ANSI.reset()]
    end
  end

  defp effect_to_ansi(:bold), do: IO.ANSI.bright()
  defp effect_to_ansi(:dim), do: IO.ANSI.faint()
  defp effect_to_ansi(:italic), do: IO.ANSI.italic()
  defp effect_to_ansi(:underline), do: IO.ANSI.underline()
  defp effect_to_ansi(:strikethrough), do: IO.ANSI.crossed_out()
  defp effect_to_ansi(:reverse), do: IO.ANSI.reverse()
  defp effect_to_ansi(:blink), do: IO.ANSI.blink_slow()
  defp effect_to_ansi(:hidden), do: IO.ANSI.conceal()
  defp effect_to_ansi(_), do: []
end
