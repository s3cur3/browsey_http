defmodule BrowseyHttp.ResponseTest do
  use ExUnit.Case, async: true

  doctest BrowseyHttp.Response

  test "status_name/1" do
    assert BrowseyHttp.Response.status_name(200) == "OK"
    assert BrowseyHttp.Response.status_name(404) == "Not Found"

    for status <- 100..999 do
      name = BrowseyHttp.Response.status_name(status)
      assert is_binary(name)
    end
  end
end
