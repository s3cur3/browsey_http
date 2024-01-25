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

  test "host_without_subdomains/1 can drop subdomains" do
    www = URI.parse("https://www.example.com")
    assert Util.Uri.host_without_subdomains(www) == "example.com"

    dashboard = URI.parse("https://dashboard.example.com")
    assert Util.Uri.host_without_subdomains(dashboard) == "example.com"

    many_subdomains = URI.parse("https://www1.www2.example.com")
    assert Util.Uri.host_without_subdomains(many_subdomains) == "example.com"
  end

  test "host_without_subdomains/1 handles bogus URIs" do
    www = URI.parse("https://not-a-domain")
    assert Util.Uri.host_without_subdomains(www) == "not-a-domain"

    dashboard = URI.parse("bogus")
    assert is_nil(Util.Uri.host_without_subdomains(dashboard))
  end
end
