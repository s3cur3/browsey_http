defmodule BrowseyHttp.BypassHelpers do
  @moduledoc false
  import Plug.Conn, only: [put_resp_header: 3, resp: 3]

  def bypass_html(bypass, path, html, headers \\ []),
    do: bypass_200(bypass, path, html, "text/html", headers)

  def bypass_xml(bypass, path, xml), do: bypass_200(bypass, path, xml, "text/xml")
  def bypass_js(bypass, path, js), do: bypass_200(bypass, path, js, "text/javascript")
  def bypass_css(bypass, path, css), do: bypass_200(bypass, path, css, "text/css")
  def bypass_png(bypass, path, png), do: bypass_200(bypass, path, png, "image/png")
  def bypass_svg(bypass, path, svg), do: bypass_200(bypass, path, svg, "image/xml+svg")

  def bypass_favicon(bypass, body \\ "") do
    Bypass.stub(
      bypass,
      "GET",
      "/favicon.ico",
      &(&1 |> put_resp_header("content-type", "image/x-icon") |> resp(200, body))
    )
  end

  def bypass_html_fixture(bypass, path, fixture_file, headers \\ []) do
    bypass_html(bypass, path, File.read!("test/support/fixtures/html/#{fixture_file}"), headers)
  end

  def bypass_200(bypass, path, body, content_type, additional_headers \\ []) do
    Bypass.expect_once(bypass, "GET", path, fn conn ->
      conn =
        Enum.reduce(
          [{"content-type", content_type} | additional_headers],
          conn,
          fn {key, value}, conn ->
            put_resp_header(conn, key, value)
          end
        )

      resp(conn, 200, body)
    end)
  end

  def bypass_301(bypass, path, redirect_to) do
    Bypass.expect_once(bypass, "GET", path, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("location", redirect_to)
      |> Plug.Conn.resp(301, "")
    end)
  end

  def bypass_404(bypass, path, body, content_type \\ "text/html") do
    Bypass.expect_once(
      bypass,
      "GET",
      path,
      &(&1 |> put_resp_header("content-type", content_type) |> resp(404, body))
    )
  end

  def bypass_error(bypass, path, status) do
    Bypass.expect_once(
      bypass,
      "GET",
      path,
      &resp(&1, status, "error")
    )
  end

  def bypass_error_with_retries(bypass, path, status) do
    Bypass.expect(
      bypass,
      "GET",
      path,
      &resp(&1, status, "error")
    )
  end
end
