defmodule Ant.Test.Assertions do
  @moduledoc """
  Custom assertions for testing.
  """

  defmacro assert_lists_contain_same(left, right, equals_by \\ nil) do
    quote do
      left_sorted = Enum.sort(unquote(left))
      right_sorted = Enum.sort(unquote(right))

      if unquote(equals_by) do
        left_mapped = Enum.map(left_sorted, &Map.get(&1, unquote(equals_by)))
        right_mapped = Enum.map(right_sorted, &Map.get(&1, unquote(equals_by)))

        assert left_mapped == right_mapped,
               "Lists are not equal. Expected: #{inspect(right_mapped)}, got: #{inspect(left_mapped)}"
      else
        assert left_sorted == right_sorted,
               "Lists are not equal. Expected: #{inspect(right_sorted)}, got: #{inspect(left_sorted)}"
      end
    end
  end
end
