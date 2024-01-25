defmodule BrowseyHttp.Util.UriTest do
  use ExUnit.Case, async: true

  alias BrowseyHttp.Util

  test "canonical_uri/2 accepts fully qualified URLs" do
    for protocol <- ["http", "https"] do
      relative_to_uri = URI.parse("https://google.com")
      fully_qualified_url = protocol <> "://example.com"

      assert Util.Uri.canonical_uri(fully_qualified_url, relative_to_uri) ==
               URI.parse(fully_qualified_url)
    end
  end
end
