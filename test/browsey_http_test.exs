defmodule BrowseyHttpTest do
  use ExUnit.Case, async: true

  import BrowseyHttp.BypassHelpers

  alias BrowseyHttp.ConnectionException
  alias BrowseyHttp.SslException
  alias BrowseyHttp.TimeoutException
  alias BrowseyHttp.TooLargeException
  alias BrowseyHttp.TooManyRedirectsException

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

    assert {:ok, %BrowseyHttp.Response{} = resp} = BrowseyHttp.get(url)
    assert %{"content-type" => ["not/real"], "foo" => ["bar: baz"]} = resp.headers
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
end
