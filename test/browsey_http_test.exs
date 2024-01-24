defmodule BrowseyHttpTest do
  use ExUnit.Case, async: true

  import BrowseyHttp.BypassHelpers

  alias BrowseyHttp.TimeoutException

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

  test "gets the status of the response", %{bypass: bypass, url: url} do
    for status <- [200, 404, 429, 500, 100] do
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
                 URI.parse(url),
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

      {:ok, %BrowseyHttp.Response{} = response} = BrowseyHttp.get(url)
      assert response.status == 301
      assert response.body == "redirecting"
      assert response.final_uri == URI.parse("#{url}/target19")

      redirected_to_uris = for i <- 1..19, do: URI.parse("#{url}/target#{i}")
      assert response.uri_sequence == [URI.parse(url) | redirected_to_uris]
    end

    test "supports *not* following redirects" do
      assert false, "implement me"
    end
  end

  test "supports timeouts" do
    assert false, "implement me"
  end

  describe "retrying" do
    # TODO: Disable "retry: got response with status 500" error logs
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

      assert {:ok, resp} = BrowseyHttp.get(url, max_retries: 2)
      assert resp.status == 200
      assert resp.body == success_result
      assert resp.final_uri == URI.parse(url)
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
      assert resp.final_uri == URI.parse(url)
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
               BrowseyHttp.get("http://httpbin.org/delay/1", timeout: 0)

      receive do
        msg -> flunk("Should not have received a message: #{inspect(msg)}")
      after
        3_000 -> :ok
      end
    end
  end

  test "supports setting a max_response_size_bytes" do
    assert false, "TODO: Implement me"
  end

  test "handles infinitely streaming resources" do
    # multipart/x-mixed-replace is a MIME type for infinitely streaming resources
    # Sample where we should only load the first part: https://dubbelboer.com/multipart.php
  end

  test "handles images" do
    assert false, "Implement me"
  end

  test "aborts responses that are too large" do
    assert false, "Implement me"
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
end
