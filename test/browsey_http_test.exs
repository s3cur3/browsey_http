defmodule BrowseyHttpTest do
  use ExUnit.Case, async: true

  import BrowseyHttp.BypassHelpers

  alias BrowseyHttp.ConnectionException
  alias BrowseyHttp.SslException
  alias BrowseyHttp.TimeoutException
  alias BrowseyHttp.TooLargeException
  alias BrowseyHttp.TooManyRedirectsException

  @never_responding_localhost_url "http://localhost:49"
  @never_responding_localhost_uri URI.parse(@never_responding_localhost_url)

  setup do
    bypass = Bypass.open()

    %{
      bypass: bypass,
      url: "http://localhost:#{bypass.port}",
      domain: "localhost:#{bypass.port}"
    }
  end

  test "retrieves the body of a page", %{bypass: bypass, url: url} do
    page_body = """
    <!DOCTYPE html>
    <html>
      <head>
        <title>Test Page</title>
      </head>
      <body>
        <h1>Test Page</h1>
        
        <p>This is a test page.</p>
      </body>
    </html>
    """

    Bypass.expect(bypass, "GET", "/", fn conn ->
      Plug.Conn.resp(conn, 200, page_body)
    end)

    assert {:ok, %BrowseyHttp.Response{} = resp} = BrowseyHttp.get(url)
    assert resp.body == page_body
  end

  test "retrieves headers", %{bypass: bypass, url: url} do
    Bypass.expect(bypass, "GET", "/", fn conn ->
      conn
      |> Plug.Conn.put_resp_header("content-type", "not/real")
      |> Plug.Conn.put_resp_header("foo", "bar: baz")
      |> Plug.Conn.resp(200, "ok")
    end)

    resp = BrowseyHttp.get!(url)
    assert %{"content-type" => ["not/real"], "foo" => ["bar: baz"]} = resp.headers
  end

  test "get!/2 raises on failure" do
    assert_raise ConnectionException, fn ->
      BrowseyHttp.get!(@never_responding_localhost_url)
    end
  end

  test "gets the status of the response", %{bypass: bypass, url: url} do
    for status <- [200, 404, 429, 500] do
      Bypass.expect(bypass, "GET", "/#{status}", fn conn ->
        Plug.Conn.resp(conn, status, "OK")
      end)

      assert {:ok, %BrowseyHttp.Response{} = resp} = BrowseyHttp.get(url <> "/#{status}")
      assert resp.status == status
    end
  end

  describe "redirects on GET requests" do
    test "follows redirects on GET requests", %{bypass: bypass, url: url} do
      dest_content = "followed all redirects"

      for status <- [301, 302, 308] do
        Bypass.expect_once(bypass, "GET", "/", fn conn ->
          conn
          |> Plug.Conn.put_resp_header("location", "/target1")
          |> Plug.Conn.resp(status, "redirecting")
        end)

        Bypass.expect_once(bypass, "GET", "/target1", fn conn ->
          conn
          |> Plug.Conn.put_resp_header("location", "/target2")
          |> Plug.Conn.resp(status, "redirecting again")
        end)

        Bypass.expect_once(bypass, "GET", "/target2", fn conn ->
          Plug.Conn.resp(conn, 200, dest_content)
        end)

        {:ok, %BrowseyHttp.Response{} = response} = BrowseyHttp.get(url)
        assert response.status == 200
        assert response.body == dest_content
        assert response.final_uri == URI.parse("#{url}/target2")

        assert response.uri_sequence == [
                 URI.parse("#{url}/"),
                 URI.parse("#{url}/target1"),
                 URI.parse("#{url}/target2")
               ]
      end
    end

    test "passes cookies along on subsequent requests", %{bypass: bypass, url: url} do
      cookie_key = "lorem"
      cookie_val = "ipsum"

      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "/target")
        |> Plug.Conn.put_resp_cookie(cookie_key, cookie_val)
        |> Plug.Conn.resp(301, "redirecting")
      end)

      test_pid = self()

      Bypass.expect_once(bypass, "GET", "/target", fn conn ->
        conn = Plug.Conn.fetch_cookies(conn)
        send(test_pid, {:cookies, conn.req_cookies})

        Plug.Conn.resp(conn, 200, "<html>OK</html>")
      end)

      {:ok, %BrowseyHttp.Response{} = response} = BrowseyHttp.get(url)
      assert response.status == 200
      assert response.uri_sequence == [URI.parse(url <> "/"), URI.parse("#{url}/target")]

      assert_receive {:cookies, cookies}
      assert %{^cookie_key => ^cookie_val} = cookies
    end

    test "aborts after too many redirects", %{bypass: bypass, url: url} do
      status = 301

      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "/target1")
        |> Plug.Conn.resp(status, "redirecting")
      end)

      for i <- 1..20 do
        Bypass.stub(bypass, "GET", "/target#{i}", fn conn ->
          conn
          |> Plug.Conn.put_resp_header("location", "/target#{i + 1}")
          |> Plug.Conn.resp(status, "redirecting")
        end)
      end

      assert {:error, %TooManyRedirectsException{} = error} = BrowseyHttp.get(url)
      assert error.max_redirects == 19
      assert error.uri == URI.parse(url)
    end

    test "supports *not* following redirects", %{bypass: bypass, url: url} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "/target1")
        |> Plug.Conn.resp(301, "redirecting")
      end)

      {:ok, %BrowseyHttp.Response{} = response} = BrowseyHttp.get(url, follow_redirects?: false)
      assert response.status == 301
      assert response.final_uri == URI.parse(url <> "/")
      assert response.uri_sequence == [URI.parse(url <> "/")]
    end
  end

  test "supports timeouts", %{bypass: bypass, url: url} do
    Bypass.stub(bypass, "GET", "/", fn conn ->
      Process.sleep(1_000)
      Plug.Conn.resp(conn, 200, "OK")
    end)

    assert {:error, %TimeoutException{} = exception} = BrowseyHttp.get(url, timeout: 1)
    assert exception.uri == URI.parse(url)
    assert exception.timeout_ms == 1
  end

  describe "retrying" do
    @tag capture_log: true
    test "retries up to max_retries", %{bypass: bypass, url: url} do
      success_result = "it worked!"

      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        Bypass.expect_once(bypass, "GET", "/", fn conn ->
          Bypass.expect_once(bypass, "GET", "/", fn conn ->
            Plug.Conn.resp(conn, 200, success_result)
          end)

          Plug.Conn.resp(conn, 500, "internal error")
        end)

        Plug.Conn.resp(conn, 500, "internal error")
      end)

      assert {:ok, %BrowseyHttp.Response{} = resp} = BrowseyHttp.get(url, max_retries: 2)
      assert resp.status == 200
      assert resp.body == success_result
      assert resp.final_uri == URI.parse(url <> "/")
      assert resp.uri_sequence == [resp.final_uri]
    end

    @tag capture_log: true
    test "aborts retrying past max_retries", %{bypass: bypass, url: url} do
      Bypass.expect(bypass, "GET", "/", fn conn ->
        Plug.Conn.resp(conn, 500, "internal error")
      end)

      assert {:ok, resp} = BrowseyHttp.get(url, max_retries: 2)
      assert resp.body == "internal error"
      assert resp.status == 500
      assert resp.final_uri == URI.parse(url <> "/")
      assert resp.uri_sequence == [resp.final_uri]
    end
  end

  describe "streaming responses" do
    @tag integration: true
    test "do not send exit messages under normal conditions", %{bypass: bypass, url: url} do
      bypass_html(bypass, "/", "OK")
      assert {:ok, %BrowseyHttp.Response{}} = BrowseyHttp.get(url, timeout: 500)

      receive do
        _ -> flunk("Should not have received a message")
      after
        1_000 -> :ok
      end
    end

    @tag integration: true
    @tag timeout: 5_000
    test "does not send exit messages on timeout" do
      assert {:error, %TimeoutException{}} =
               BrowseyHttp.get("http://httpbin.org/delay/1", timeout: 1)

      receive do
        msg -> flunk("Should not have received a message: #{inspect(msg)}")
      after
        3_000 -> :ok
      end
    end
  end

  test "supports setting a max_response_size_bytes", %{bypass: bypass, url: url} do
    giant_page = "<html>" <> String.duplicate("<a href='/'>Link</a>", 266_000) <> "</html>"
    bypass_html(bypass, "/", giant_page)

    assert {:error, %TooLargeException{} = exception} =
             BrowseyHttp.get(url, max_response_size_bytes: 1024)

    assert exception.uri == URI.parse(url)
    assert exception.max_bytes == 1024
  end

  @tag todo: true
  test "handles infinitely streaming resources" do
    # multipart/x-mixed-replace is a MIME type for infinitely streaming resources
    # Sample where we should only load the first part: https://dubbelboer.com/multipart.php
  end

  test "handles images", %{bypass: bypass, url: url} do
    png_binary = <<137, 80, 78, 71, 13, 10, 26, 10, 0>>
    bypass_png(bypass, "/image.png", png_binary)

    assert {:ok, %BrowseyHttp.Response{} = resp} = BrowseyHttp.get(url <> "/image.png")
    assert resp.body == png_binary
    assert resp.status == 200
    assert resp.headers["content-type"] == ["image/png"]
  end

  describe "handling brotli-compressed responses" do
    test "works for Netlify pages", %{bypass: bypass, url: url} do
      bypass_html_fixture(bypass, "/", "tylerayoung.com.br", [{"content-encoding", "br"}])
      assert {:ok, %BrowseyHttp.Response{body: body}} = BrowseyHttp.get(url)

      assert String.valid?(body)

      assert {:ok, parsed} = Floki.parse_document(body)
      text = Floki.text(parsed)
      assert text =~ "Tyler A. Young"
      assert text =~ "Rapid Unscheduled Learning"
    end

    test "works for crafted.ie", %{bypass: bypass, url: url} do
      bypass_html_fixture(bypass, "/", "crafted.ie.br", [{"content-encoding", "br"}])
      assert {:ok, %BrowseyHttp.Response{body: body}} = BrowseyHttp.get(url)

      assert String.valid?(body)

      assert {:ok, parsed} = Floki.parse_document(body)
      text = Floki.text(parsed)
      assert text =~ "Living Room"
      assert text =~ "Free Shipping"
    end

    test "works for facebook.com", %{bypass: bypass, url: url} do
      bypass_html_fixture(bypass, "/", "facebook.com.br", [{"content-encoding", "br"}])
      assert {:ok, %BrowseyHttp.Response{body: body}} = BrowseyHttp.get(url)

      assert String.valid?(body)

      assert {:ok, parsed} = Floki.parse_document(body)
      text = Floki.text(parsed)
      assert text =~ "Facebook"
      assert text =~ "log in"
    end

    test "works for wordpress.org", %{bypass: bypass, url: url} do
      bypass_html_fixture(bypass, "/", "wordpress.org.br", [{"content-encoding", "br"}])
      assert {:ok, %BrowseyHttp.Response{body: body}} = BrowseyHttp.get(url)

      assert String.valid?(body)

      assert {:ok, parsed} = Floki.parse_document(body)
      text = Floki.text(parsed)
      assert text =~ "WordPress"
      assert text =~ "See what's new"
    end
  end

  describe "choosing a browser" do
    @user_agents %{
      chrome: "Chrome/116.0.0.0",
      edge: "Edg/101.0.1210.47",
      android: "Chrome/99.0.4844.58",
      safari: "Safari/605.1.15"
    }
    test "can choose a specific browser", %{bypass: bypass, url: url} do
      test_pid = self()

      Bypass.expect(bypass, "GET", "/", fn conn ->
        send(test_pid, {:header, Plug.Conn.get_req_header(conn, "user-agent")})
        Plug.Conn.resp(conn, 200, "OK")
      end)

      for {browser, expected_text} <- @user_agents do
        BrowseyHttp.get(url, browser: browser)
        assert_receive {:header, [ua_header]}
        assert ua_header =~ expected_text
      end
    end

    test "can choose random", %{bypass: bypass, url: url} do
      test_pid = self()

      Bypass.expect(bypass, "GET", "/", fn conn ->
        send(test_pid, {:header, Plug.Conn.get_req_header(conn, "user-agent")})
        Plug.Conn.resp(conn, 200, "OK")
      end)

      for _ <- 1..10 do
        BrowseyHttp.get(url, browser: :random)
      end

      assert_receive {:header, [ua_header_1]}
      assert_receive {:header, [ua_header_2]}
      assert_receive {:header, [ua_header_3]}
      assert_receive {:header, [ua_header_4]}
      assert_receive {:header, [ua_header_5]}
      assert_receive {:header, [ua_header_6]}
      assert_receive {:header, [ua_header_7]}
      assert_receive {:header, [ua_header_8]}
      assert_receive {:header, [ua_header_9]}
      assert_receive {:header, [ua_header_10]}

      user_agents =
        Enum.uniq([
          ua_header_1,
          ua_header_2,
          ua_header_3,
          ua_header_4,
          ua_header_5,
          ua_header_6,
          ua_header_7,
          ua_header_8,
          ua_header_9,
          ua_header_10
        ])

      assert length(user_agents) > 1
    end
  end

  @tag integration: true
  test "identifies bad SSL certificates" do
    for url <- [
          "https://expired.badssl.com/",
          "https://wrong.host.badssl.com/",
          "https://self.signed.badssl.com/"
        ] do
      assert {:error, %SslException{} = error} = BrowseyHttp.get(url)
      assert error.uri == URI.parse(url)
    end
  end

  test "identifies malformed urls" do
    for url <- [
          "",
          "http://",
          "https://",
          "https:// this isn't a url",
          "this isn't a url",
          "example.com"
        ] do
      assert {:error, %ConnectionException{} = error} = BrowseyHttp.get(url)
      assert error.uri == URI.parse(url)
    end
  end

  @tag integration: true
  test "identifies nonexistent domains" do
    for url <- [
          "http://browsey-http-not-a-host-#{System.unique_integer()}.de",
          "https://browsey-http-not-a-host-#{System.unique_integer()}.de"
        ] do
      assert {:error, %ConnectionException{} = error} = BrowseyHttp.get(url)
      assert error.uri == URI.parse(url)
      assert error.error_code == 6
    end
  end

  test "handles failure to connect" do
    assert {:error, %ConnectionException{} = error} =
             BrowseyHttp.get(@never_responding_localhost_url)

    assert error.uri == @never_responding_localhost_uri
    assert error.error_code == 7
  end

  describe "get_with_resources/2" do
    test "fetches CSS, JS, and images", %{bypass: bypass, url: url} do
      html = """
      <html>
        <head>
          <script src='/javascript.js' />
          <link rel='stylesheet' href='dir/app.css' />
        </head>
        <body>
          <img src='#{url}/img/image.png' />
        </body>
      </html>
      """

      css = "img { url(image-from-css.png); }"
      js = "use strict; function() { }"
      png = <<137, 80, 78, 71, 13, 10, 26, 10, 0>>
      ico = <<1, 0, 0, 1, 0, 0, 1>>

      bypass_html(bypass, "/", html)
      bypass_css(bypass, "/dir/app.css", css)
      bypass_js(bypass, "/javascript.js", js)
      bypass_png(bypass, "/img/image.png", png)
      bypass_favicon(bypass, ico)

      assert {:ok, responses} = BrowseyHttp.get_with_resources(url)
      assert length(responses) == 5

      uris = Enum.map(responses, & &1.final_uri)
      assert hd(uris) == URI.parse(url <> "/")

      paths = Enum.map(uris, & &1.path)

      assert Enum.sort(paths) ==
               Enum.sort(["/", "/favicon.ico", "/dir/app.css", "/javascript.js", "/img/image.png"])

      assert Enum.all?(responses, &(&1.status == 200))

      css_resp = Enum.find(responses, &(&1.final_uri.path == "/dir/app.css"))
      assert css_resp.headers["content-type"] == ["text/css"]
      assert css_resp.body == css

      js_resp = Enum.find(responses, &(&1.final_uri.path == "/javascript.js"))
      assert js_resp.headers["content-type"] == ["text/javascript"]
      assert js_resp.body == js

      png_resp = Enum.find(responses, &(&1.final_uri.path == "/img/image.png"))
      assert png_resp.headers["content-type"] == ["image/png"]
      assert png_resp.body == png

      ico_resp = Enum.find(responses, &(&1.final_uri.path == "/favicon.ico"))
      assert ico_resp.headers["content-type"] == ["image/x-icon"]
      assert ico_resp.body == ico

      html_resp = Enum.find(responses, &(&1.final_uri.path == "/"))
      assert html_resp.headers["content-type"] == ["text/html"]
      assert html_resp.body == html
    end

    test "handles protocol-relative URLs", %{bypass: bypass, url: url} do
      html = """
      <html>
        <body>
          <img src='#{String.replace(url, "http:", "")}/img/image.png' />
        </body>
      </html>
      """

      png = <<137, 80, 78, 71, 13, 10, 26, 10, 0>>

      bypass_html(bypass, "/", html)
      bypass_png(bypass, "/img/image.png", png)
      bypass_favicon(bypass)

      assert {:ok, [_ | images]} = BrowseyHttp.get_with_resources(url)

      assert length(images) == 2
      assert Enum.any?(images, &(&1.final_uri.path == "/favicon.ico"))

      assert png_resp = Enum.find(images, &(&1.final_uri.path == "/img/image.png"))

      assert png_resp.headers["content-type"] == ["image/png"]
      assert png_resp.body == png
    end

    test "does not crawl the same resource twice", %{bypass: bypass, url: url} do
      html = """
      <html>
        <head>
          <script src='/javascript.js' />
          <script src='/javascript.js' />
          <script src='javascript.js' />
          <link rel='stylesheet' href='/dir/app.css' />
          <link rel='stylesheet' href='dir/app.css' />
          <link rel='stylesheet' href='#{url}/dir/app.css' />
          <link rel='icon shortcut' href='/favicon.png' />
        </head>
        <body>
          <img src='#{url}/img/image.png' />
          <img src='/img/image.png' />
          <img src='img/image.png' />
        </body>
      </html>
      """

      css = "img { url(image-from-css.png); }"
      js = "use strict; function() { }"
      png = <<137, 80, 78, 71, 13, 10, 26, 10, 0>>

      bypass_html(bypass, "/", html)
      bypass_css(bypass, "/dir/app.css", css)
      bypass_js(bypass, "/javascript.js", js)
      bypass_png(bypass, "/img/image.png", png)
      bypass_png(bypass, "/favicon.png", png)

      assert {:ok, responses} = BrowseyHttp.get_with_resources(url)
      assert length(responses) == 5

      response_paths = Enum.map(responses, & &1.final_uri.path)

      assert Enum.sort(response_paths) ==
               Enum.sort(["/", "/dir/app.css", "/javascript.js", "/img/image.png", "/favicon.png"])
    end

    test "handles failure to get the initial page" do
      assert {:error, %ConnectionException{} = exception} =
               BrowseyHttp.get_with_resources(@never_responding_localhost_url)

      assert exception.uri == @never_responding_localhost_uri
    end

    test "handles failure to get resources", %{bypass: bypass, url: url} do
      html = """
      <html>
        <head>
          <link rel='stylesheet' href='/dir/app.css' />
          <script src='#{@never_responding_localhost_url}' />
        </head>
        <body>OK</body>
      </html>
      """

      bypass_html(bypass, "/", html)
      bypass_404(bypass, "/dir/app.css", "Not Found")

      assert {:ok, responses} = BrowseyHttp.get_with_resources(url, fetch_images?: false)
      assert length(responses) == 3

      [primary_resp | resource_resps] = responses
      assert primary_resp.status == 200
      assert primary_resp.body == html

      {[connection_exception], [css_resp]} =
        Enum.split_with(resource_resps, &match?(%ConnectionException{}, &1))

      assert css_resp.final_uri.path == "/dir/app.css"
      assert css_resp.status == 404

      assert connection_exception.uri == @never_responding_localhost_uri
    end

    test "handles binary responses", %{bypass: bypass, url: url} do
      png_binary = <<137, 80, 78, 71, 13, 10, 26, 10, 0>>
      bypass_png(bypass, "/image.png", png_binary)

      assert {:ok, [response]} = BrowseyHttp.get_with_resources("#{url}/image.png")

      assert response.status == 200
      assert response.body == png_binary
    end

    test "handles non-HTML responses", %{bypass: bypass, url: url} do
      body = "This is not actually HTML"
      bypass_html(bypass, "/", body)
      bypass_favicon(bypass)

      assert {:ok, [response, favicon]} = BrowseyHttp.get_with_resources(url)

      assert response.status == 200
      assert response.body == body

      assert favicon.status == 200
      assert favicon.headers["content-type"] == ["image/x-icon"]
      assert is_binary(favicon.body)
    end
  end
end

defmodule BrowseyHttpSyncTest do
  # Synchronous due to use of Patch
  use ExUnit.Case, async: false
  use Patch

  import BrowseyHttp.BypassHelpers

  setup do
    bypass = Bypass.open()

    %{
      bypass: bypass,
      url: "http://localhost:#{bypass.port}",
      domain: "localhost:#{bypass.port}"
    }
  end

  test "handles parse failure from Floki", %{bypass: bypass, url: url} do
    Patch.patch(Floki, :parse_document, {:error, :parse_error})

    body = "This is not actually HTML"
    bypass_html(bypass, "/", body)

    assert {:ok, [response]} = BrowseyHttp.get_with_resources(url)

    assert response.status == 200
    assert response.body == body
  end
end
