defmodule BrowseyHttp do
  @moduledoc """
  BrowseyHttp is a browser-imitating HTTP client for scraping websites that resist bot traffic.

  Browsey aims to behave as much like a real browser as possible, short of executing JavaScript.
  It's able to scrape sites that are notoriously difficult, including:

  - LinkedIn
  - Amazon
  - Real estate sites including Zillow, Realtor.com, and Trulia
  - Sites protected by Cloudflare
  - Sites protected by DataDome, including Reddit, AllTrails, and RealClearPolitics

  Plus, as a customer of Browsey, if you encounter a site Browsey can't scrape, we'll make
  a best effort attempt to get a fix for you. (Fully client-side rendered sites, though, will
  still not be supported.)

  Note that when scraping, you'll need to be mindful of both the IPs you're scraping from and
  how many requests you're sending to a given site. Too much traffic from a given IP will trip
  rate limits even if you *were* using a real browser. (For instance, if you try to scrape any
  major site within your CI system, it's almost guaranteed to fail. A shared IP on a cloud
  server is iffy as well.)

  ## Why BrowseyHttp?

  ### Browsey versus other HTTP clients

  Because Browsey imitates a real browser beyond just faking a user agents, it is able to
  scrape *vastly* more sites than a default-configured HTTP client like HTTPoison, Finch,
  or Req, which get blocked by Cloudflare and other anti-bot measures.

  ### Browsey versus Selenium, Chromedriver, Playwright, etc.

  Running a real, headless web browser is the gold standard for fooling bot detection, and
  it's the *only* way to scrape sites that are fully client-side rendered. However, running
  a real browser is extremely resource-intensive; it's not uncommon to encounter a site that
  will cause Chromedriver to use 6 GB of RAM or more. Headless browsers are also quite a
  bit slower than Browsey, since you end up waiting for the page to render, execute
  JavaScript, etc.

  Worst of all, headless browsers can be unreliable. If you run a hundred requests, you'll
  encounter at least a few that fail in ways that aren't related to the site you're
  scraping having issues. Chromedriver may simply fail to respond to your commands for
  reasons that are impossible to diagnose. It may time out waiting for JavaScript to finish
  executing, and of course browsers can crash.

  In contrast, Browsey is extremely reliable (it's too simple to fail in complicated ways like
  browsers do!), and it requires virtually no resources beyond the memory needed to store
  the response data. It also has built-in protections to ensure memory usage doesn't
  spiral out of control (see the `:max_response_size_bytes` option to `BrowseyHttp.get/2`).
  Finally, Browsey is quite a bit faster than a headless browser.

  ### Browsey versus a third-party scraping service like Zyte, ScrapeHero, or Apify

  Third-party scraping APIs are billed as a complete, no-compromise solution for web scraping,
  but they often have reliability problems. You're essentially paying someone else to run
  a headless browser for you, but they're subject to the same issues as the headless browsers
  themselves in terms of reliability. It doesn't feel great to pay the high prices of a
  scraping service only to get back a failure unrelated to the site you're scraping being down.

  Because of its reliability, flat monthly price, and low resource consumption,
  Browsey makes a better *first* choice for your scraping needs. Then you can fall back to
  expensive third-party APIs when you encounter a site that really needs a headless browser.
  """
  alias BrowseyHttp.Html
  alias BrowseyHttp.TimeoutException
  alias BrowseyHttp.TooLargeException
  alias BrowseyHttp.Util

  require Logger

  @max_response_size_mb 5
  @max_response_size_bytes @max_response_size_mb * 1024 * 1024

  @type uri_or_url :: URI.t() | String.t()
  @type get_result :: {:ok, BrowseyHttp.Response.t()} | {:error, Exception.t()}

  @type http_get_option ::
          {:follow_redirects?, boolean()}
          | {:max_retries, non_neg_integer()}
          | {:additional_headers, BrowseyHttp.Response.headers()}
          | {:max_response_size_bytes, non_neg_integer() | :infinity}
          | {:receive_timeout, timeout()}
          | {:force_brotli_support?, boolean()}

  # Matches Chrome's behavior:
  # https://stackoverflow.com/questions/10895406/what-is-the-maximum-number-of-http-redirections-allowed-by-all-major-browsers
  @max_redirects 19

  @doc """
  Performs an HTTP GET request for a single resource, limiting the size we process to protect the server.

  Note that to fully imitate a browser, you may want to instead use
  `BrowseyHttp.get_with_resources/2` to retrieve both the page itself and its
  embedded resources (CSS, JavaScript, images, etc.) at once.

  ### Options

  - `:max_response_size_bytes`: The maximum size of the response body, in bytes, or `:infinity`.
     If the response body exceeds this size, we'll raise a `TooLargeException`. This is important
     so that unintentionally downloading, say, a huge video file doesn't run your server out
     of memory. Defaults to 5,242,880 (5 MiB).
  - `:follow_redirects?`: whether to follow redirects. Defaults to true, in which case the
     complete chain of redirects will be tracked in the `BrowseyHttp.Response` struct's
     `:uri_sequence` field.
  - `:max_retries`: how many times to retry when the HTTP status code indicates an error.
     Defaults to 0.
  - `:additional_headers`: headers we'll send (in addition to browser-imitating headers), in
     Req's map format (a map from the header name to a list of values). See the
     `BrowseyHttp.Response.headers()` type for more info.
  - `:force_brotli_support?`: If true, we'll include Brotli in the list of accepted encodings.
     By default, we do not advertise Brotli support, because initial requests to sites from
     real browser do not.
  - `:receive_timeout`: The maximum time (in milliseconds) to wait to receive a response after
    connecting to the server. Defaults to 30,000 (30 seconds).

  ### Examples

      iex> case BrowseyHttp.get("https://www.example.com") do
      ...>   {:ok, %BrowseyHttp.Response{body: body}} -> String.slice(body, 0, 15)
      ...>   {:error, exception} -> exception
      ...> end
      "<!doctype html>"
  """
  @spec get(uri_or_url(), [http_get_option()]) :: get_result()
  def get(url_or_uri, opts \\ []) do
    {:ok, get!(url_or_uri, opts)}
  rescue
    e -> {:error, e}
  end

  @spec get!(uri_or_url(), [http_get_option()]) :: BrowseyHttp.Response.t() | no_return
  def get!(url_or_uri, opts \\ []) do
    follow_redirects? = Keyword.get(opts, :follow_redirects?, true)
    start_time = DateTime.utc_now()

    url_or_uri
    |> get_internal!([], opts)
    |> Util.then_if(follow_redirects?, &follow_redirects!(&1, opts))
    |> finalize_response(start_time)
  end

  @type resource_option ::
          {:ignore_uris, Enumerable.t(URI.t())}
          | {:fetch_images?, boolean()}
          | {:fetch_css?, boolean()}
          | {:fetch_js?, boolean()}
          | {:load_resources_when_redirected_off_host?, boolean()}

  @type resource_responses :: [BrowseyHttp.Response.t() | Exception.t()]

  @doc """
  Performs an HTTP GET request for a resource plus any embedded resources (CSS, JavaScript, images, etc.).

  This matches how a real browser fetches a page by retrieving the resources in parallel.

  On success, the first of the returned response structs will always be the initial HTML page.

  If the initial HTML page fails to load, we'll return an error tuple. However, if any of the
  embedded resources fail to load entirely (that is, they don't merely return an HTTP error
  like a 404, but they would cause an `:error` return from `BrowseyHttp.get/2`, such as a
  no-such-domain error or a timeout), they'll simply be left out of the returned response list.

  If the initial resource we retrieve is not HTML, on success we'll return an ok tuple
  with a single response struct.

  ### Options

  - Control the individual requests using the same options as `BrowseyHttp.get/2`.
  - `:ignore_uris`: An enumerable of URI structs that we will skip fetching when they
    are referenced as resources. You can use this to do things like avoid re-crawling
    images that are present in the header of every page. Defaults to the empty set.
  - `:fetch_images?`: Whether to fetch images referenced in `<img>` and `<link rel="icon">` tags.
    Defaults to true.
  - `:fetch_css?`: Whether to fetch CSS files referenced in `<link rel="stylesheet">` tags.
    Defaults to true.
  - `:fetch_js?`: Whether to fetch JavaScript files referenced in `<script>` tags.
    Defaults to true.
  - `:load_resources_when_redirected_off_host?`: If false, we'll skip crawling resources if
    the URL redirects to a different host. Defaults to false to prevent unintentionally
    loading resources from a site you didn't expect.
  """
  @spec get_with_resources(uri_or_url(), [http_get_option() | resource_option()]) ::
          {:ok, [BrowseyHttp.Response.t() | resource_responses]} | {:error, Exception.t()}
  def get_with_resources(url_or_uri, opts \\ []) do
    case stream_with_resources(url_or_uri, opts) do
      {:ok, responses} -> {:ok, Enum.to_list(responses)}
      error -> error
    end
  end

  @doc """
  Same as `BrowseyHttp.get_with_resources/2`, but when the primary result succeeds, returns a stream of responses.

  As with the non-streaming version, the first response will always be the initial resource.
  """
  @spec stream_with_resources(uri_or_url(), [http_get_option() | resource_option()]) ::
          {:ok, Enumerable.t(BrowseyHttp.Response.t() | resource_responses)}
          | {:error, Exception.t()}
  def stream_with_resources(url_or_uri, opts \\ []) do
    case get(url_or_uri, opts) do
      {:ok, resp} ->
        if BrowseyHttp.Response.html?(resp) and crawl_resources?(resp, opts) do
          {:ok, Stream.concat([resp], stream_embedded_resources(resp, opts))}
        else
          {:ok, [resp]}
        end

      error ->
        error
    end
  end

  defp real_browser_headers(for_url, opts) do
    host = URI.parse(for_url).host

    accept_encoding =
      if opts[:force_brotli_support?] do
        "gzip, deflate, br"
      else
        "gzip, deflate"
      end

    Enum.random([
      # Safari
      %{
        "Accept" => ["text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"],
        "Accept-Encoding" => [accept_encoding],
        "Accept-Language" => ["en-US,en;q=0.9"],
        "Connection" => ["keep-alive"],
        "Host" => [host],
        "User-Agent" => [
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
        ]
      },
      # Firefox
      %{
        "Accept" => [
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"
        ],
        "Accept-Encoding" => [accept_encoding],
        "Accept-Language" => ["en-US,en;q=0.5"],
        "Connection" => ["keep-alive"],
        "Host" => [host],
        "Upgrade-Insecure-Requests" => ["1"],
        "User-Agent" => [
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:120.0) Gecko/20100101 Firefox/120.0"
        ]
      },
      # Chrome
      %{
        "Accept" => [
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
        ],
        "Accept-Encoding" => [accept_encoding],
        "Accept-Language" => ["en-US,en;q=0.9"],
        "Cache-Control" => ["max-age=0"],
        "Connection" => ["keep-alive"],
        "Host" => [host],
        "Upgrade-Insecure-Requests" => ["1"],
        "User-Agent" => [
          "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        ]
      }
    ])
  end

  @spec get_internal!(uri_or_url(), [URI.t()], Keyword.t()) ::
          BrowseyHttp.Response.t() | no_return
  defp get_internal!(url_or_uri, prev_uris, opts) do
    headers =
      url_or_uri
      |> real_browser_headers(opts)
      |> Map.merge(opts[:additional_headers] || %{})

    max_retries = Keyword.get(opts, :max_retries, 0)
    receive_timeout = Access.get(opts, :timeout, :timer.seconds(30))

    [
      # If we ever go back to Finch as the request runner instead of Hackney/HTTPoison,
      # we'll need to run this through url_encode/1.
      url: url_or_uri,
      headers: headers,
      # Custom headers will specify compression
      compressed: false,
      receive_timeout: receive_timeout,
      # We use our own redirect handling
      redirect: false,
      retry: max_retries > 0 and (&should_retry?/2),
      retry_delay: &retry_delay_slow/1,
      max_retries: max_retries,
      # into: &accumulate_response!/2,
      adapter: &run_request!(&1, opts)
    ]
    |> Req.new()
    |> Req.Request.append_request_steps(headers: &replace_headers_case_sensitive(&1, headers))
    |> Req.Request.append_response_steps(iodata_to_binary: &concat_iodata/1)
    |> Req.Request.append_response_steps(decompress_brotli: &decompress_brotli/1)
    |> Req.Request.append_response_steps(decompress: &Req.Steps.decompress_body/1)
    |> Req.get!()
    |> browsey_response_from_req(url_or_uri, prev_uris)
  end

  defp browsey_response_from_req(%Req.Response{} = resp, url_or_uri, prev_uris) do
    uri = URI.parse(url_or_uri)

    %BrowseyHttp.Response{
      body: resp.body,
      headers: resp.headers,
      status: resp.status,
      final_uri: uri,
      uri_sequence: [uri | prev_uris],
      runtime_ms: 0
    }
  end

  defp run_request!(%Req.Request{} = request, opts) do
    headers = BrowseyHttp.Response.headers_to_proplist(request.headers)
    timeout = request.options.receive_timeout
    max_size_bytes = Access.get(opts, :max_response_size_bytes, @max_response_size_bytes)

    # Hackney does not rewrite foo.com?bar=baz to foo.com/?bar=baz, so we do it ourselves.
    uri =
      case request.url do
        %URI{path: nil} = uri when byte_size(uri.query) > 0 or byte_size(uri.fragment) > 0 ->
          %{uri | path: "/"}

        uri ->
          uri
      end

    url = to_string(uri)

    fn ->
      try do
        # Hackney, unlike Finch, does not forcibly downcase our header names.
        # Cloudflare uses this as a huge signal as to whether or not we're a bot.
        case HTTPoison.get(url, headers,
               max_body_length: max_size_bytes,
               recv_timeout: timeout + 200,
               stream_to: self(),
               async: :once
             ) do
          {:ok, %HTTPoison.AsyncResponse{} = async_response} ->
            try do
              deadline = Util.Time.ms_from_now(timeout)

              {request,
               accumulate_req_response(
                 async_response,
                 deadline,
                 request.url,
                 max_size_bytes
               )}
            after
              :hackney.stop_async(async_response.id)
            end

          {:error, %HTTPoison.Error{reason: reason}} ->
            {request, RuntimeError.exception(inspect(reason))}
        end
      catch
        # This is the error Hackney raises when exceeding the max response size
        _, %ErlangError{original: :data_error, reason: nil} ->
          {request, TooLargeException.response_body_exceeds_bytes(max_size_bytes, request.url)}

        _, reason ->
          {request, RuntimeError.exception(inspect(reason))}
      end
    end
    |> Util.DoNotDisturb.run_silent(timeout + 1_000)
    |> case do
      {:ok, result} -> result
      {:error, :timeout} -> {request, TimeoutException.timed_out(uri, timeout)}
    end
  end

  @spec accumulate_req_response(
          HTTPoison.AsyncResponse.t(),
          DateTime.t(),
          URI.t(),
          non_neg_integer() | :infinity,
          Req.Response.t()
        ) ::
          Req.Response.t() | Exception.t()
  defp accumulate_req_response(
         %HTTPoison.AsyncResponse{id: response_id} = resp,
         %DateTime{} = deadline,
         %URI{} = uri,
         max_size_bytes,
         out \\ %Req.Response{status: 200, headers: %{}, body: []}
       ) do
    receive do
      %HTTPoison.AsyncStatus{code: status, id: ^response_id} ->
        # TODO: Handle error result
        _ = HTTPoison.stream_next(resp)
        accumulate_req_response(resp, deadline, uri, max_size_bytes, %{out | status: status})

      %HTTPoison.AsyncHeaders{headers: headers, id: ^response_id} ->
        map_headers = BrowseyHttp.Response.proplist_to_headers(headers)

        with true <- is_integer(max_size_bytes),
             [bytes_str | _] <- map_headers["content-length"],
             {bytes, ""} <- Integer.parse(bytes_str),
             true <- bytes > max_size_bytes do
          # TODO: Telemetry to observe that we aborted
          TooLargeException.content_length_exceeded(bytes, max_size_bytes, uri)
        else
          _ ->
            # TODO: Handle error result
            _ = HTTPoison.stream_next(resp)
            updated_resp = %{out | headers: map_headers}
            accumulate_req_response(resp, deadline, uri, max_size_bytes, updated_resp)
        end

      %HTTPoison.AsyncChunk{chunk: chunk, id: ^response_id} ->
        # Produces an improper list, but it's okay! It's an iolist!
        # https://dorgan.netlify.app/posts/2021/03/making-sense-of-elixir-(improper)-lists/
        appended = [out.body | chunk]

        if is_integer(max_size_bytes) and :erlang.iolist_size(appended) > max_size_bytes do
          # TODO: Telemetry to observe that we aborted
          TooLargeException.response_body_exceeds_bytes(max_size_bytes, uri)
        else
          # TODO: Handle error result
          _ = HTTPoison.stream_next(resp)
          accumulate_req_response(resp, deadline, uri, max_size_bytes, %{out | body: appended})
        end

      %HTTPoison.AsyncEnd{id: ^response_id} ->
        out
    after
      # Irritatingly, it seems we can't use a variable timeout
      # (produced by `Util.Time.ms_until(deadline)`) here directly
      100 ->
        if Util.Time.deadline_passed?(deadline) do
          case out.headers["content-type"] do
            ["multipart/x-mixed-replace" <> _ | _] ->
              # This is a potentially infinitely streaming response, so it not having ended
              # is not an error.
              out

            _ ->
              TimeoutException.timed_out(uri)
          end
        else
          accumulate_req_response(resp, deadline, uri, max_size_bytes, out)
        end
    end
  end

  defp finalize_response(%BrowseyHttp.Response{} = resp, start_time) do
    runtime_ms = DateTime.diff(DateTime.utc_now(), start_time, :millisecond)
    %{resp | uri_sequence: Enum.reverse(resp.uri_sequence), runtime_ms: runtime_ms}
  end

  defp follow_redirects!(resp, opts, depth \\ 1)

  defp follow_redirects!(%BrowseyHttp.Response{status: status} = resp, opts, depth)
       when status in 300..399 and depth <= @max_redirects do
    case redirect_to_url(resp.headers, resp.final_uri) do
      {:ok, %URI{} = redirect_to} ->
        cookie_headers = resp.headers["set-cookie"] || []

        opts =
          Keyword.update(
            opts,
            :additional_headers,
            %{"cookie" => cookie_headers},
            &Map.put(&1, "cookie", cookie_headers)
          )

        redirect_to
        |> get_internal!(resp.uri_sequence, opts)
        |> follow_redirects!(opts, depth + 1)

      _ ->
        resp
    end
  end

  defp follow_redirects!(%BrowseyHttp.Response{} = resp, _, _), do: resp

  defp redirect_to_url(headers, relative_to_url) when is_binary(relative_to_url) do
    redirect_to_url(headers, URI.parse(relative_to_url))
  end

  defp redirect_to_url(headers, %URI{} = relative_to) do
    case headers["location"] do
      [url | _] -> {:ok, URI.merge(relative_to, URI.parse(url))}
      _ -> :error
    end
  end

  defp replace_headers_case_sensitive(%Req.Request{} = req, headers) do
    %{req | headers: headers}
  end

  # defp accumulate_response!({:data, chunk}, {req, resp}) do
  #   resp = Req.Response.update_private(resp, :acc_bytes, 0, &(&1 + byte_size(chunk)))

  #   if resp.private[:acc_bytes] <= @max_response_size_bytes do
  #     {:cont, {req, append_chunk(resp, chunk)}}
  #   else
  #     # TODO: Telemetry to observe that we aborted
  #     raise TooLargeException, message: "Response body exceeds #{@max_response_size_mb} MB"
  #   end
  # end

  # defp append_chunk(%Req.Response{body: ""} = resp, chunk), do: %{resp | body: [chunk]}
  # defp append_chunk(%Req.Response{body: body} = resp, chunk), do: %{resp | body: body ++ [chunk]}

  defp concat_iodata({%Req.Request{} = request, %Req.Response{} = response}) do
    {%{request | into: nil}, %{response | body: IO.iodata_to_binary(response.body)}}
  end

  defp decompress_brotli({%Req.Request{} = request, %Req.Response{} = response}) do
    content_encodings =
      response
      |> Req.Response.get_header("content-encoding")
      |> Enum.join(",")
      |> String.split(",", trim: true)
      |> Enum.uniq()
      |> Enum.map(&String.trim/1)

    case content_encodings do
      ["br" | tail] ->
        updated_headers = Map.put(response.headers, "content-encoding", tail)
        {:ok, decompressed} = ExBrotli.decompress(response.body)
        {request, %{response | body: decompressed, headers: updated_headers}}

      _ ->
        {request, response}
    end
  end

  defp should_retry?(_req, %Req.Response{status: status}) do
    status >= 400
  end

  defp should_retry?(_req, %{__exception__: true, reason: :timeout}), do: true
  defp should_retry?(_req, %{__exception__: true, reason: :econnrefused}), do: true
  defp should_retry?(_req, %{__exception__: true}), do: false

  defp stream_embedded_resources(%BrowseyHttp.Response{final_uri: uri} = resp, opts) do
    case Floki.parse_document(resp.body) do
      {:ok, parsed} ->
        ignore_uris = MapSet.new(opts[:ignore_uris] || [])
        fetch = Access.get(opts, :get, &get(&1, opts))

        # A browser would load these resources inline, without any throttling, so it's
        # safe for us to do so as well.
        uris_to_fetch =
          parsed
          |> Html.urls_a_browser_would_load_immediately(opts)
          |> MapSet.new(&BrowseyHttp.Uri.canonical_uri(&1, uri))
          |> MapSet.difference(ignore_uris)

        uris_to_fetch
        |> Task.async_stream(fetch,
          max_concurrency: min(4, System.schedulers_online()),
          ordered: false,
          timeout: MapSet.size(uris_to_fetch) * :timer.minutes(1),
          on_timeout: :kill_task
        )
        |> Stream.filter(&match?({:ok, _}, &1))
        |> Stream.map(fn {:ok, result} -> result end)
        |> Stream.map(fn
          {:ok, result} -> result
          {:error, exception} -> exception
        end)

      _ ->
        []
    end
  end

  defp crawl_resources?(%BrowseyHttp.Response{} = resp, opts) do
    %BrowseyHttp.Response{final_uri: %URI{} = final, uri_sequence: [%URI{} = first | _]} = resp
    opts[:load_resources_when_redirected_off_host?] || final.host == first.host
  end

  # TODO: Make this configurable
  if Mix.env() == :test do
    defp retry_delay_slow(retry_count), do: 1 + retry_count
  else
    # Exponential backoff starting at 4 seconds, then 8, 16, etc.
    defp retry_delay_slow(retry_count), do: :timer.seconds(2 ** (3 + retry_count))
  end
end
