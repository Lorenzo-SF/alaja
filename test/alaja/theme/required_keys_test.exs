defmodule Alaja.Theme.RequiredKeysTest do
  use ExUnit.Case, async: true

  alias Alaja.Theme.RequiredKeys

  describe "required/0 + size/0" do
    test "returns the 22-key contract in alphabetical order" do
      assert RequiredKeys.required() == Enum.sort(RequiredKeys.required())
      assert RequiredKeys.size() == 22
    end

    test "no duplicate keys" do
      assert length(Enum.uniq(RequiredKeys.required())) == RequiredKeys.size()
    end
  end

  describe "missing/1 + validate/1 + valid?/1" do
    test "missing returns every key when the map is empty" do
      assert length(RequiredKeys.missing(%{})) == 22
    end

    test "validate returns :ok for a complete contract map" do
      complete =
        Enum.reduce(RequiredKeys.required(), %{}, fn key, acc ->
          Map.put(acc, key, {1, 2, 3})
        end)

      assert RequiredKeys.validate(complete) == :ok
      assert RequiredKeys.valid?(complete)
    end

    test "validate returns {:error, missing} for an incomplete map" do
      incomplete = %{"primary" => {1, 2, 3}, "alert" => {4, 5, 6}}
      {:error, missing} = RequiredKeys.validate(incomplete)

      assert "primary" not in missing
      assert "alert" not in missing
      assert "background" in missing
      assert length(missing) == 20
    end

    test "extra keys do not affect validation" do
      base =
        Enum.reduce(RequiredKeys.required(), %{}, fn key, acc ->
          Map.put(acc, key, {1, 2, 3})
        end)

      extras = Map.merge(base, %{"rosewater" => {244, 219, 214}, "mauve" => {198, 160, 246}})
      assert RequiredKeys.validate(extras) == :ok
    end
  end

  describe "fill/1" do
    test "fills missing required keys with white" do
      incomplete = %{"primary" => {10, 20, 30}, "alert" => {40, 50, 60}}

      filled = RequiredKeys.fill(incomplete)

      assert filled["primary"] == {10, 20, 30}
      assert filled["alert"] == {40, 50, 60}
      assert filled["background"] == {255, 255, 255}
      assert filled["success"] == {255, 255, 255}
    end

    test "preserves user-supplied values when present" do
      complete =
        Enum.reduce(RequiredKeys.required(), %{}, fn key, acc ->
          Map.put(acc, key, {1, 1, 1})
        end)

      filled = RequiredKeys.fill(complete)

      Enum.each(RequiredKeys.required(), fn key ->
        assert filled[key] == {1, 1, 1}
      end)
    end

    test "annotates __missing__ and __extra__" do
      incomplete = %{"primary" => {0, 0, 0}, "alert" => {0, 0, 0}, "rosewater" => {1, 2, 3}}
      filled = RequiredKeys.fill(incomplete)

      assert "background" in filled[:__missing__]
      assert filled[:__extra__] == ["rosewater"]
    end

    test "complete theme with extras has no __missing__" do
      complete =
        RequiredKeys.required()
        |> Enum.reduce(%{}, fn key, acc -> Map.put(acc, key, {1, 1, 1}) end)
        |> Map.put("rosewater", {1, 2, 3})
        |> Map.put("mauve", {4, 5, 6})

      filled = RequiredKeys.fill(complete)
      assert filled[:__missing__] == []
      assert "rosewater" in filled[:__extra__]
      assert "mauve" in filled[:__extra__]
    end
  end
end
