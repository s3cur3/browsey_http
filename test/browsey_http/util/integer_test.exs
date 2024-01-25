defmodule BrowseyHttp.IntegerTest do
  use ExUnit.Case, async: true

  alias BrowseyHttp.Util

  test "trims leading and trailing spaces" do
    assert Util.Integer.from_string(" 123 ") == {:ok, 123}
    assert Util.Integer.from_string("123\r\n") == {:ok, 123}
    assert Util.Integer.from_string("\t123") == {:ok, 123}
  end

  test "returns error on invalid input" do
    assert Util.Integer.from_string("not an integer") == :error
    assert Util.Integer.from_string("123 foo") == :error
    assert Util.Integer.from_string("123?") == :error
  end
end
