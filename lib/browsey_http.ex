defmodule BrowseyHttp do
  @moduledoc """
  BrowseyHttp is a browser-imitating HTTP client for scraping websites that resist bot traffic.

  Browsey aims to behave as much like a real browser as possible, short of executing JavaScript.
  It's able to scrape sites that are notoriously difficult, including:

  - LinkedIn
  - Amazon
  - Udemy
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

  @spec get_internal!(uri_or_url(), [URI.t()], Keyword.t()) ::
          BrowseyHttp.Response.t() | no_return
  defp get_internal!(url_or_uri, prev_uris, opts) do
    browser_script = Enum.random(available_browsers())
    script = Application.app_dir(:browsey_http, ["priv", "curl", browser_script])

    # TODO: Parse out headers (and pass -v to the script)
    # TODO: Support opts[:additional_headers]
    # TODO: Support retries
    # TODO: Support receive_timeout = Access.get(opts, :timeout, :timer.seconds(30))
    # TODO: Don't follow redirects if we're not supposed to
    # Someday We could use the `:into` argument to stream and parse the request as it goes...

    # case System.cmd(script, [to_string(url_or_uri), "-v"], opts) do
    #   {output, 0} -> curl_output_to_response(output, url_or_uri, prev_uris)
    #   output -> raise RuntimeError, message: "Failed to download response: #{inspect(output)}"
    # end

    timeout = Access.get(opts, :timeout, :timer.seconds(30))

    :exec.start()

    case :exec.run("#{script} -v #{to_string(url_or_uri)}", [:sync, :stdout, :stderr], timeout) do
      {:ok, [stdout: body_parts, stderr: meta]} ->
        body = Enum.join(body_parts, "")
        curl_output_to_response(body, meta, url_or_uri, prev_uris)

      error ->
        raise RuntimeError, message: "Failed to download response: #{inspect(error)}"
    end
  end

  defp available_browsers do
    ["curl_chrome99_android", "curl_chrome116", "curl_edge101", "curl_safari15_5"]
  end

  defp curl_output_to_response(curl_output, metadata, url_or_uri, prev_uris) do
    IO.inspect(metadata, label: "metadata")
    uri = URI.parse(url_or_uri)

    %BrowseyHttp.Response{
      body: curl_output,
      headers: %{},
      # TODO: Get the request status
      status: 200,
      final_uri: uri,
      uri_sequence: [uri | prev_uris],
      runtime_ms: 0
    }
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
