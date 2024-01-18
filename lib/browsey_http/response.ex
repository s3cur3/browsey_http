defmodule BrowseyHttp.Response do
  @moduledoc """
  A response from a browser-imitating HTTP request.
  """
  use TypedStruct

  @typedoc """
  Headers sent with a request or returned in a response from the server.

  Maps response header names (all lowercase, like `"content-encoding"`)
  to the values associated with that header. This is structured as a map, the way the
  [`Req`](https://hexdocs.pm/req/readme.html) library does, to make it clear that servers
  may legitimately send multiple values for the same header name.

  You can use `BrowseyHttp.Response.headers_to_proplist/1` to convert this to the
  format used by HTTP clients like Finch or HTTPoison, and you can use
  `BrowseyHttp.Response.proplist_to_headers/1` to convert *from* that format to this one.
  """
  @type headers :: %{optional(binary()) => [binary()]}

  typedstruct enforce: true do
    @typedoc """
    Fields on a response:

    - `:body`: the response body. For HTML documents, this will always be a `String.t()`, but
      for binary files like images and videos, it will be non-Unicode binary data.
    - `:headers`: a map from response header names (all lowercase, like `"content-encoding"`)
      to the values associated with that header. This is structured as a map, the way the
      [`Req`](https://hexdocs.pm/req/readme.html) library does, to make it clear that servers
      may legitimately send multiple values for the same header name.
    - `:status`: the HTTP status code returned by the final URL in the chain of redirects,
      like `200` or `404`.
    - `:final_uri`: the final URL in the chain of redirects, as a
      [`URI`](https://hexdocs.pm/elixir/URI.html).
    - `:uri_sequence`: the complete chain of URLs that were visited (length 1 if there were no
      redirects), as a list of [`URI`](https://hexdocs.pm/elixir/URI.html)s. The first element
      will always be URL that was passed to `BrowseyHttp.get/2`, and the last will always be
      the `:final_uri`.
    - `:runtime_ms`: the number of milliseconds the request took to complete, including
      all redirects.
    """
    field :body, binary()
    field :headers, headers()
    field :status, non_neg_integer()
    field :final_uri, URI.t()
    field :uri_sequence, nonempty_list(URI.t())
    field :runtime_ms, timeout()
  end

  @typep has_uri_sequence :: %{:uri_sequence => nonempty_list(URI.t()), optional(atom) => any}

  @doc """
  The original URL passed to `BrowseyHttp.get/2`, before any redirects.
  """
  @spec original_uri(t() | has_uri_sequence) :: URI.t()
  def original_uri(%{uri_sequence: [uri | _]}), do: uri

  @typep has_headers :: %{:headers => headers(), optional(atom) => any}

  @doc """
  Converts our headers from a map to a list of 2-tuples in the format used by Finch or HTTPoison.

  ### Examples

      iex> BrowseyHttp.Response.headers_to_proplist(%{body: "...", headers: %{"content-type" => ["text/html"]}})
      [{"content-type", "text/html"}]

      iex> BrowseyHttp.Response.headers_to_proplist(%{body: "...", headers: %{"content-encoding" => ["gzip", "br"]}})
      [{"content-encoding", "gzip"}, {"content-encoding", "br"}]

  """
  @spec headers_to_proplist(t() | has_headers() | headers()) :: [{String.t(), String.t()}]
  def headers_to_proplist(response_or_headers)
  def headers_to_proplist(%{headers: headers}), do: headers_to_proplist(headers)

  def headers_to_proplist(headers) when is_map(headers) and not is_struct(headers) do
    Enum.flat_map(headers, fn {name, values} ->
      Enum.map(values, fn value -> {name, value} end)
    end)
  end

  @doc """
  Converts headers in the 2-tuple format used by Finch or HTTPoison to a map used by `BrowseyHttp.get/2`.

  ### Examples

      iex> BrowseyHttp.Response.proplist_to_headers([{"Content-Type", "text/html"}])
      %{"content-type" => ["text/html"]}

      iex> BrowseyHttp.Response.proplist_to_headers([{"content-encoding", "gzip"}, {"content-encoding", "br"}])
      %{"content-encoding" => ["gzip", "br"]}
  """
  @spec proplist_to_headers([{String.t(), String.t()}]) :: headers()
  def proplist_to_headers(proplist_headers) do
    Enum.reduce(proplist_headers, %{}, fn {name, value}, acc ->
      Map.update(acc, String.downcase(name), [value], &(&1 ++ [value]))
    end)
  end

  @doc """
  The human readable title for an HTTP error status code.
  """
  @spec status_name(non_neg_integer()) :: String.t()
  def status_name(status)
  def status_name(300), do: "Multiple Choices"
  def status_name(301), do: "Moved Permanently"
  def status_name(302), do: "Found"
  def status_name(303), do: "See Other"
  def status_name(304), do: "Not Modified"
  def status_name(305), do: "Use Proxy"
  def status_name(307), do: "Temporary Redirect"
  def status_name(308), do: "Permanent Redirect"
  def status_name(400), do: "Bad Request"
  def status_name(401), do: "Unauthorized"
  def status_name(402), do: "Payment Required"
  def status_name(403), do: "Forbidden"
  def status_name(404), do: "Not Found"
  def status_name(405), do: "Method Not Allowed"
  def status_name(406), do: "Not Acceptable"
  def status_name(407), do: "Proxy Authentication Required"
  def status_name(408), do: "Request Timeout"
  def status_name(409), do: "Conflict"
  def status_name(410), do: "Gone"
  def status_name(411), do: "Length Required"
  def status_name(412), do: "Precondition Failed"
  def status_name(413), do: "Payload Too Large"
  def status_name(414), do: "Request-URI Too Long"
  def status_name(415), do: "Unsupported Media Type"
  def status_name(416), do: "Requested Range Not Satisfiable"
  def status_name(417), do: "Expectation Failed"
  def status_name(418), do: "I'm a teapot"
  def status_name(421), do: "Misdirected Request"
  def status_name(422), do: "Unprocessable Entity"
  def status_name(423), do: "Locked"
  def status_name(424), do: "Failed Dependency"
  def status_name(425), do: "Too Early"
  def status_name(426), do: "Upgrade Required"
  def status_name(428), do: "Precondition Required"
  def status_name(429), do: "Too Many Requests"
  def status_name(431), do: "Request Header Fields Too Large"
  def status_name(444), do: "Connection Closed Without Response"
  def status_name(451), do: "Unavailable For Legal Reasons"
  def status_name(499), do: "Client Closed Request"
  def status_name(500), do: "Internal Server Error"
  def status_name(501), do: "Not Implemented"
  def status_name(502), do: "Bad Gateway"
  def status_name(503), do: "Service Unavailable"
  def status_name(504), do: "Gateway Timeout"
  def status_name(505), do: "HTTP Version Not Supported"
  def status_name(506), do: "Variant Also Negotiates"
  def status_name(507), do: "Insufficient Storage"
  def status_name(508), do: "Loop Detected"
  def status_name(510), do: "Not Extended"
  def status_name(511), do: "Network Authentication Required"
  def status_name(520), do: "Web Server Returned an Unknown Error"
  def status_name(521), do: "Web Server Is Down"
  def status_name(522), do: "Connection Timed Out"
  def status_name(523), do: "Origin Is Unreachable"
  def status_name(524), do: "A Timeout Occurred"
  def status_name(525), do: "SSL Handshake Failed"
  def status_name(526), do: "Invalid SSL Certificate"
  def status_name(527), do: "Railgun Error"
  def status_name(530), do: "Cloudflare error"
  def status_name(599), do: "Network Connect Timeout"
  def status_name(_), do: ""

  @typep has_headers_and_body :: %{
           :headers => headers(),
           :body => binary(),
           optional(atom) => any
         }

  @doc """
  True if the response appears to be HTML, either based on its headers or its body content.
  """
  @spec html?(has_headers_and_body) :: boolean
  def html?(%{headers: headers} = resp) do
    html_headers?(resp) or (headers["content-type"] in [nil, []] and html_body?(resp))
  end

  defp html_headers?(%{headers: %{"content-type" => [content_type | _]}}) do
    content_type
    |> String.downcase()
    |> String.contains?(["text/html", "application/xhtml+xml"])
  end

  defp html_headers?(_), do: false

  defp html_body?(%{body: body}) when is_binary(body) do
    head_length = String.length("<!DOCTYPE html")

    body
    |> String.trim_leading()
    |> String.slice(0..head_length)
    |> String.downcase()
    |> String.starts_with?(["<!doctype html", "<html"])
  end

  defp html_body?(%{}), do: false
end
