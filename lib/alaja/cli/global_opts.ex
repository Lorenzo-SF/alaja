defmodule Alaja.CLI.GlobalOpts do
  @moduledoc """
  Definition and extraction of global CLI options shared across commands.

  Global options are parsed from raw args before command-specific parsing
  so they are available to every subcommand.
  """

  @type t :: %__MODULE__{
          help: boolean(),
          raw: boolean(),
          pos_x: non_neg_integer(),
          pos_y: non_neg_integer(),
          align: :left | :center | :right,
          verbose: boolean(),
          box: boolean(),
          box_title: String.t() | nil,
          box_border: atom(),
          box_color: tuple() | nil,
          bg_color: tuple() | nil,
          quiet: boolean(),
          stdin: boolean(),
          no_color: boolean(),
          color: boolean()
        }

  defstruct help: false,
            raw: false,
            pos_x: 0,
            pos_y: 0,
            align: :left,
            verbose: false,
            box: false,
            box_title: nil,
            box_border: :rounded,
            box_color: nil,
            bg_color: nil,
            quiet: false,
            stdin: false,
            no_color: false,
            color: false

  # ---------------------------------------------------------------------------
  # Extraction
  # ---------------------------------------------------------------------------

  @doc """
  Parses global options from raw args, returning {global_opts, remaining_args}.

  Only recognizes known global flags; all other args are passed through.
  """
  @spec parse([String.t()]) :: {t(), [String.t()]}
  def parse(args) do
    {global_opts, rest} = extract_globals(args, %__MODULE__{})
    {global_opts, rest}
  catch
    :invalid_global -> exit({:shutdown, 1})
  end

  defp extract_globals([], acc), do: {acc, []}

  defp extract_globals(["--help" | rest], acc), do: extract_globals(rest, %{acc | help: true})
  defp extract_globals(["-h" | rest], acc), do: extract_globals(rest, %{acc | help: true})

  defp extract_globals(["--raw" | rest], acc), do: extract_globals(rest, %{acc | raw: true})
  defp extract_globals(["-r" | rest], acc), do: extract_globals(rest, %{acc | raw: true})

  defp extract_globals(["--pos-x", val | rest], acc) do
    case Integer.parse(val) do
      {n, _} ->
        extract_globals(rest, %{acc | pos_x: n})

      :error ->
        IO.puts(:stderr, "Error: --pos-x requires an integer, got '#{val}'")
        throw(:invalid_global)
    end
  end

  defp extract_globals(["--pos-y", val | rest], acc) do
    case Integer.parse(val) do
      {n, _} ->
        extract_globals(rest, %{acc | pos_y: n})

      :error ->
        IO.puts(:stderr, "Error: --pos-y requires an integer, got '#{val}'")
        throw(:invalid_global)
    end
  end

  defp extract_globals(["--align", val | rest], acc) do
    extract_globals(rest, %{acc | align: parse_align(val)})
  end

  defp extract_globals(["-a", val | rest], acc) do
    extract_globals(rest, %{acc | align: parse_align(val)})
  end

  defp extract_globals(["--verbose" | rest], acc),
    do: extract_globals(rest, %{acc | verbose: true})

  defp extract_globals(["-v" | rest], acc), do: extract_globals(rest, %{acc | verbose: true})

  defp extract_globals(["--box" | rest], acc), do: extract_globals(rest, %{acc | box: true})

  defp extract_globals(["--box-title", val | rest], acc) do
    extract_globals(rest, %{acc | box_title: val})
  end

  defp extract_globals(["--box-border", val | rest], acc) do
    border =
      case Alaja.Helpers.safe_string_to_atom(val) do
        {:ok, atom} -> atom
        {:error, _} -> :rounded
      end

    extract_globals(rest, %{acc | box_border: border})
  end

  defp extract_globals(["--box-color", val | rest], acc) do
    color = parse_color(val)
    extract_globals(rest, %{acc | box_color: color})
  end

  defp extract_globals(["--bg-color", val | rest], acc) do
    color = parse_color(val)
    extract_globals(rest, %{acc | bg_color: color})
  end

  defp extract_globals(["--quiet" | rest], acc), do: extract_globals(rest, %{acc | quiet: true})
  defp extract_globals(["-q" | rest], acc), do: extract_globals(rest, %{acc | quiet: true})

  defp extract_globals(["--stdin" | rest], acc), do: extract_globals(rest, %{acc | stdin: true})
  defp extract_globals(["-s" | rest], acc), do: extract_globals(rest, %{acc | stdin: true})

  defp extract_globals(["--no-color" | rest], acc),
    do: extract_globals(rest, %{acc | no_color: true})

  defp extract_globals(["--color" | rest], acc),
    do: extract_globals(rest, %{acc | color: true})

  # Unknown flag with value: keep both
  defp extract_globals([flag, val | rest], acc) do
    if String.starts_with?(flag, "--") do
      {acc2, rest2} = extract_globals(rest, acc)
      {acc2, [flag, val | rest2]}
    else
      {acc2, rest2} = extract_globals([val | rest], acc)
      {acc2, [flag | rest2]}
    end
  end

  # Unknown flag or positional: keep it
  defp extract_globals([arg | rest], acc) do
    {acc2, rest2} = extract_globals(rest, acc)
    {acc2, [arg | rest2]}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp parse_align("left"), do: :left
  defp parse_align("center"), do: :center
  defp parse_align("right"), do: :right
  defp parse_align(a) when is_atom(a), do: a
  defp parse_align(_), do: :left

  defp parse_color(str) do
    case Alaja.CLI.Color.parse(str) do
      {:ok, rgb} ->
        rgb

      {:error, msg} ->
        IO.puts(:stderr, msg)
        nil

      nil ->
        nil
    end
  end

  @doc """
  Converts global opts to printer keyword opts.
  """
  @spec to_printer_opts(t()) :: keyword()
  def to_printer_opts(global) do
    [
      raw: global.raw,
      pos_x: global.pos_x,
      pos_y: global.pos_y,
      verbose: global.verbose,
      box: global.box,
      box_title: global.box_title,
      box_border: global.box_border,
      box_color: global.box_color,
      bg_color: global.bg_color,
      align: global.align,
      no_color: global.no_color,
      color: global.color
    ]
  end
end
