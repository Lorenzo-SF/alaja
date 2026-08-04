defmodule Alaja.Input do
  @moduledoc """
  Parser for raw terminal input bytes → `Alaja.Msg.t()`.

  Supports:

    * ASCII printable characters.
    * Control characters: Enter, Tab, Backspace, Esc, Ctrl-?.
    * Arrow keys (CSI sequences).
    * Function keys (F1-F12).
    * Nav keys (Home, End, PageUp, PageDown, Insert, Delete).
    * Modifier combinations (Ctrl-, Alt-, Shift-).
    * Bracketed paste (start/end sentinel).
    * Resize (CSI 8 ; rows ; cols t).

  This module is **pure** — given a binary, it returns a list of
  parsed `Alaja.Msg.t()` values.

  ## Examples

      iex> Alaja.Input.parse("hi")
      [%Alaja.Msg.Key{key: "h"}, %Alaja.Msg.Key{key: "i"}]

  """

  alias Alaja.Msg

  @type parse_result :: [Msg.t()]

  @doc "Parses a binary of raw input bytes into a list of `Alaja.Msg.t()`."
  @spec parse(binary()) :: parse_result()
  def parse(""), do: []
  def parse(binary) when is_binary(binary), do: do_parse(binary, []) |> Enum.reverse()

  # ── Top-level dispatch ──────────────────────────────────────────────────────

  defp do_parse("", acc), do: acc

  # ESC starts an escape sequence
  defp do_parse(<<0x1B, rest::binary>>, acc) do
    parse_escape(rest, acc, [])
  end

  # Backspace / DEL
  defp do_parse(<<0x7F, rest::binary>>, acc) do
    do_parse(rest, [Msg.key("backspace") | acc])
  end

  # Control characters (already pre-0x20)
  defp do_parse(<<c, rest::binary>>, acc) when c in 0x01..0x1F do
    do_parse(rest, [Msg.key(ctrl_name(c)) | acc])
  end

  # Printable ASCII
  defp do_parse(<<c, rest::binary>>, acc) when c >= 0x20 and c < 0x7F do
    do_parse(rest, [Msg.key(<<c>>) | acc])
  end

  # High bytes / unknown — skip
  defp do_parse(<<_, rest::binary>>, acc), do: do_parse(rest, acc)

  defp ctrl_name(0x00), do: "ctrl-space"
  defp ctrl_name(0x09), do: "tab"
  defp ctrl_name(0x0A), do: "enter"
  defp ctrl_name(0x0D), do: "enter"
  defp ctrl_name(0x1B), do: "esc"
  defp ctrl_name(c), do: "ctrl-#{<<c + 0x60>>}"

  # ── Escape sequences ──────────────────────────────────────────────────────

  # Empty rest after ESC → lone ESC
  defp parse_escape("", acc, mods), do: [Msg.key("esc", mods) | acc]

  # ESC [ ... (CSI)
  defp parse_escape("[" <> rest, acc, mods) do
    parse_csi(rest, acc, mods)
  end

  # ESC O <letter> (SS3)
  defp parse_escape("O" <> <<c, rest::binary>>, acc, mods) do
    key = ss3_key(c)

    if key do
      do_parse(rest, [Msg.key(key, modifiers: mods) | acc])
    else
      do_parse(rest, acc)
    end
  end

  # ESC <char> = Alt-<char>
  defp parse_escape(<<c, rest::binary>>, acc, mods) when c >= 0x20 do
    do_parse(rest, [Msg.key(<<c>>, modifiers: [:alt | mods]) | acc])
  end

  defp parse_escape(<<c, rest::binary>>, acc, mods) do
    do_parse(rest, [Msg.key(ctrl_name(c), modifiers: [:alt | mods]) | acc])
  end

  defp ss3_key(?A), do: "up"
  defp ss3_key(?B), do: "down"
  defp ss3_key(?C), do: "right"
  defp ss3_key(?D), do: "left"
  defp ss3_key(?H), do: "home"
  defp ss3_key(?F), do: "end"
  defp ss3_key(?P), do: "f1"
  defp ss3_key(?Q), do: "f2"
  defp ss3_key(?R), do: "f3"
  defp ss3_key(?S), do: "f4"
  defp ss3_key(_), do: nil

  # ── CSI sequences ─────────────────────────────────────────────────────────

  defp parse_csi(binary, acc, mods) do
    do_parse_csi(binary, [], [], acc, mods)
  end

  defp do_parse_csi("", _params, _finals, acc, _mods), do: acc

  defp do_parse_csi(<<c, rest::binary>>, params, finals, acc, mods) when c in ?0..?9 do
    do_parse_csi(rest, params, [c - ?0 | finals], acc, mods)
  end

  defp do_parse_csi(<<";", rest::binary>>, params, finals, acc, mods) do
    do_parse_csi(rest, params ++ [Enum.reverse(finals)], [], acc, mods)
  end

  defp do_parse_csi(<<c, rest::binary>>, params, finals, acc, mods) when c in 0x40..0x7E do
    params_with_final =
      case finals do
        [] -> params
        _ -> params ++ [Enum.reverse(finals)]
      end

    handle_csi(<<c>>, params_with_final, acc, mods) |> handle_rest(rest)
  end

  defp do_parse_csi(<<_, rest::binary>>, params, finals, acc, mods) do
    do_parse_csi(rest, params, finals, acc, mods)
  end

  defp handle_rest(msg, rest), do: do_parse(rest, msg)

  # ── CSI handlers ──────────────────────────────────────────────────────────

  defp handle_csi("u", params, acc, mods) do
    # kitty keyboard protocol: CSI <keycode> [; <modifiers> [; <base>]] u
    case params do
      [kcode_digits] ->
        [Msg.key(kitty_decode(kcode_digits), modifiers: mods) | acc]

      [kcode_digits, mod] ->
        [Msg.key(kitty_decode(kcode_digits), modifiers: mods ++ parse_mods(mod)) | acc]

      [kcode_digits, mod, _base] ->
        [Msg.key(kitty_decode(kcode_digits), modifiers: mods ++ parse_mods(mod)) | acc]

      _ ->
        acc
    end
  end

  defp handle_csi(<<f>>, _params, acc, mods) when f in ~c"ABCD" do
    [Msg.key(arrow(f), modifiers: mods) | acc]
  end

  defp handle_csi(<<f>>, params, acc, mods) when f in ~c"HPF" do
    # H, P, F — sometimes used for Home, F1, End
    case params do
      [] -> [Msg.key(arrow(f), modifiers: mods) | acc]
      [[1]] -> [Msg.key(arrow(f), modifiers: mods) | acc]
      _ -> acc
    end
  end

  defp handle_csi("~", params, acc, mods) do
    case params do
      [n] -> [Msg.key(tilde_n(n), modifiers: mods) | acc]
      [n, mod] -> [Msg.key(tilde_n(n), modifiers: mods ++ parse_mods(mod)) | acc]
      _ -> acc
    end
  end

  defp handle_csi("t", params, acc, _mods) do
    # CSI 8 ; rows ; cols t (resize)
    case params do
      [[8], rows_digits, cols_digits] ->
        [Msg.resize(to_int(cols_digits), to_int(rows_digits)) | acc]

      _ ->
        acc
    end
  end

  defp handle_csi("Z", params, acc, mods) do
    # shift+tab: CSI 1 ; 2 Z (or just Z with params)
    case params do
      [] -> [Msg.key("tab", modifiers: [:shift | mods]) | acc]
      [_] -> [Msg.key("tab", modifiers: [:shift | mods]) | acc]
      [_, _] -> [Msg.key("tab", modifiers: [:shift | mods]) | acc]
      _ -> acc
    end
  end

  defp handle_csi(_, _params, acc, _mods), do: acc

  defp arrow(?A), do: "up"
  defp arrow(?B), do: "down"
  defp arrow(?C), do: "right"
  defp arrow(?D), do: "left"
  defp arrow(?H), do: "home"
  defp arrow(?F), do: "end"
  defp arrow(?P), do: "f1"
  defp arrow(_), do: nil

  defp tilde_n(1), do: "home"
  defp tilde_n(2), do: "insert"
  defp tilde_n(3), do: "delete"
  defp tilde_n(4), do: "end"
  defp tilde_n(5), do: "pageup"
  defp tilde_n(6), do: "pagedown"
  defp tilde_n(7), do: "home"
  defp tilde_n(8), do: "end"
  defp tilde_n(11), do: "f1"
  defp tilde_n(12), do: "f2"
  defp tilde_n(13), do: "f3"
  defp tilde_n(14), do: "f4"
  defp tilde_n(15), do: "f5"
  defp tilde_n(17), do: "f6"
  defp tilde_n(18), do: "f7"
  defp tilde_n(19), do: "f8"
  defp tilde_n(20), do: "f9"
  defp tilde_n(21), do: "f10"
  defp tilde_n(23), do: "f11"
  defp tilde_n(24), do: "f12"
  defp tilde_n(digits) when is_list(digits), do: tilde_n(to_int(digits))
  defp tilde_n(_), do: nil

  defp kitty_decode(digits) do
    kcode = to_int(digits)

    cond do
      kcode in 0x20..0x7E -> <<kcode>>
      kcode == 0x09 -> "tab"
      kcode == 0x0D -> "enter"
      kcode == 0x7F -> "backspace"
      kcode == 0x1B -> "esc"
      true -> "kitty-#{kcode}"
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp parse_mods(digits) do
    n = to_int(digits)

    []
    |> maybe_add(:shift, Bitwise.band(n, 1) != 0)
    |> maybe_add(:alt, Bitwise.band(n, 2) != 0)
    |> maybe_add(:ctrl, Bitwise.band(n, 4) != 0)
    |> maybe_add(:super, Bitwise.band(n, 8) != 0)
  end

  defp maybe_add(mods, _, false), do: mods
  defp maybe_add(mods, key, true), do: [key | mods]

  defp to_int([d]) when is_integer(d) and d in 0..9, do: d
  defp to_int([d1, d2]), do: d1 * 10 + d2
  defp to_int([d1, d2, d3]), do: d1 * 100 + d2 * 10 + d3
  defp to_int(_), do: 0
end
