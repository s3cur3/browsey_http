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

  test "original_uri/1 returns the first URI" do
    uri = URI.parse("https://google.com")
    assert BrowseyHttp.Response.original_uri(%{uri_sequence: [uri]}) == uri

    other_uris = [URI.parse("https://example.com"), URI.parse("https://example.org")]
    assert BrowseyHttp.Response.original_uri(%{uri_sequence: [uri | other_uris]}) == uri
  end

  describe "html?/1" do
    test "copes with missing content-type header" do
      assert BrowseyHttp.Response.html?(%{headers: %{}, body: "<!dOcTyPe hTmL><HtML></html>"})
      assert BrowseyHttp.Response.html?(%{headers: %{"foo" => "bar"}, body: "<hTmL></html>"})
    end

    test "copes with missing body" do
      refute BrowseyHttp.Response.html?(%{headers: %{}, body: nil})
    end
  end
end
