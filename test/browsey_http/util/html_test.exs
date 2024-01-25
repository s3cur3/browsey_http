defmodule BrowseyHttp.Util.HtmlTest do
  use ExUnit.Case, async: true

  alias BrowseyHttp.Util.Html

  describe "urls_a_browser_would_load_immediately/2" do
    @html """
    <html>
      <head>
        <script src='/javascript.js' />
        <script src='/javascript.js' />
        <script src='javascript.js' />
        <link rel='stylesheet' href='/dir/app.css' />
        <link rel='stylesheet' href='dir/app.css' />
        <link rel='stylesheet' href='http://localhost/dir/app.css' />

        <meta property='og:image' content='http://localhost/og_image.png' />
        <link rel='icon' href='http://localhost/images/custom-favicon.ico' />
        <link rel='apple-touch-icon' href='http://localhost/apple-touch-icon.png' />
        <link rel='apple-touch-icon-precomposed' href='http://localhost/apple-touch-icon-precomposed.png' />
      </head>
      <body>
        <img src='http://localhost/img/image.png' />
        <img src='/img/image.png' />
        <img src='img/image.png' />
      </body>
    </html>
    """

    @floki_document Floki.parse_document!(@html)

    test "can ignore images" do
      paths = Html.urls_a_browser_would_load_immediately(@floki_document, fetch_images?: false)

      assert Enum.sort(paths) ==
               Enum.sort([
                 "/javascript.js",
                 "javascript.js",
                 "/dir/app.css",
                 "dir/app.css",
                 "http://localhost/dir/app.css"
               ])
    end

    test "can load only images" do
      paths =
        Html.urls_a_browser_would_load_immediately(@floki_document,
          fetch_js?: false,
          fetch_css?: nil
        )

      assert Enum.sort(paths) ==
               Enum.sort([
                 "http://localhost/og_image.png",
                 "http://localhost/images/custom-favicon.ico",
                 "http://localhost/apple-touch-icon.png",
                 "http://localhost/apple-touch-icon-precomposed.png",
                 "http://localhost/img/image.png",
                 "/img/image.png",
                 "img/image.png"
               ])
    end

    test "falls back to loading favicon.ico if there are no other icons" do
      paths =
        """
        <html>
          <body>
            <img src='img/image.png' />
          </body>
        </html>
        """
        |> Floki.parse_document!()
        |> Html.urls_a_browser_would_load_immediately(fetch_js?: false, fetch_css?: nil)

      assert Enum.sort(paths) == Enum.sort(["/favicon.ico", "img/image.png"])
    end
  end

  describe "valid_link?/1" do
    test "accepts normal links" do
      assert Html.valid_link?("http://example.com")
      assert Html.valid_link?("https://example.com")
      assert Html.valid_link?("https://example.com/")
      assert Html.valid_link?("https://example.com/path")
      assert Html.valid_link?("https://example.com/path?query=string")
      assert Html.valid_link?("https://example.com/path?query=")
      assert Html.valid_link?("://example.com/path?query=")
      assert Html.valid_link?("/path")
      assert Html.valid_link?("/path/my-file.html")
      assert Html.valid_link?("/my-path/")
    end

    test "rejects links that go nowhere" do
      refute Html.valid_link?("#")
      refute Html.valid_link?("href")
      refute Html.valid_link?("data:abc123")
      refute Html.valid_link?("blob:abc123")
      refute Html.valid_link?("")
      refute Html.valid_link?(nil)
    end
  end
end
