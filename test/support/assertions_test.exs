defmodule Ant.Test.AssertionsTest do
  use ExUnit.Case
  import Ant.Test.Assertions

  describe "assert_lists_contain_same/3" do
    test "compares lists directly when no equals_by is provided" do
      list1 = [1, 3, 2]
      list2 = [2, 1, 3]
      assert_lists_contain_same(list1, list2)
    end

    test "fails when lists are not equal" do
      list1 = [1, 2, 3]
      list2 = [1, 2, 4]

      assert_raise ExUnit.AssertionError, fn ->
        assert_lists_contain_same(list1, list2)
      end
    end

    test "compares lists by a specific key" do
      list1 = [%{id: 1, name: "a"}, %{id: 2, name: "b"}]
      list2 = [%{id: 2, name: "z"}, %{id: 1, name: "y"}]
      assert_lists_contain_same(list1, list2, :id)
    end

    test "fails when lists are not equal by key" do
      list1 = [%{id: 1, name: "a"}, %{id: 2, name: "b"}]
      list2 = [%{id: 2, name: "z"}, %{id: 3, name: "y"}]

      assert_raise ExUnit.AssertionError, fn ->
        assert_lists_contain_same(list1, list2, :id)
      end
    end

    test "handles empty lists" do
      assert_lists_contain_same([], [])
    end

    test "handles lists with one element" do
      list1 = [%{id: 1, name: "a"}]
      list2 = [%{id: 1, name: "b"}]
      assert_lists_contain_same(list1, list2, :id)
    end

    test "handles lists with duplicate values" do
      list1 = [1, 2, 2, 3]
      list2 = [2, 1, 3, 2]
      assert_lists_contain_same(list1, list2)
    end

    test "handles lists with duplicate values by key" do
      list1 = [%{id: 1}, %{id: 2}, %{id: 2}, %{id: 3}]
      list2 = [%{id: 2}, %{id: 1}, %{id: 3}, %{id: 2}]
      assert_lists_contain_same(list1, list2, :id)
    end

    test "fails when lists have different lengths" do
      list1 = [1, 2, 3]
      list2 = [1, 2]

      assert_raise ExUnit.AssertionError, fn ->
        assert_lists_contain_same(list1, list2)
      end
    end

    test "fails when key doesn't exist in all elements" do
      list1 = [%{id: 1}, %{id: 2}]
      list2 = [%{id: 2}, %{other_id: 1}]

      assert_raise ExUnit.AssertionError, fn ->
        assert_lists_contain_same(list1, list2, :id)
      end
    end
  end
end
