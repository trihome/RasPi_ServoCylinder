defmodule PlcTest do
  use ExUnit.Case
  doctest Plc

  test "greets the world" do
    assert Plc.hello() == :world
  end
end
