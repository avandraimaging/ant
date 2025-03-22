defmodule Ant.TestCase do
  defmacro __using__(opts \\ []) do
    quote do
      use ExUnit.Case, unquote(opts)
      import Ant.Test.Assertions
    end
  end
end
