# browsey_http

BrowseyHttp is a browser-imitating HTTP client for scraping websites that resist bot traffic.

Browsey aims to behave as much like a real browser as possible, short of executing JavaScript.
It's able to scrape sites that are notoriously difficult, including:

- Amazon
- Google
- Udemy
- TicketMaster
- LinkedIn (at least for the first few requests per day per IP, after which even real browsers will be shown the "auth wall")
- Real estate sites including Zillow, Realtor.com, and Trulia
- OpenSea
- Sites protected by Cloudflare
- Sites protected by PerimeterX/HUMAN Security
- Sites protected by DataDome, including Reddit, AllTrails, and RealClearPolitics

Fully client-side rendered sites like Twitter, though, won't be supported; for those cases, 
you'll need to fall back to a headless browser.

Note that when scraping, you'll also need to be mindful of both the IPs you're scraping from and
how many requests you're sending to a given site. Too much traffic from a given IP, or IPs
within a major cloud provider's data center, will trip rate limits and bot detect even if
you *were* using a real browser. (For instance, if you try to scrape any
major site within your CI system, it's almost guaranteed to fail.)

## Why BrowseyHttp?

### Browsey versus other HTTP clients

Because Browsey imitates a real browser's "[fingerprint](https://github.com/FoxIO-LLC/ja4?tab=readme-ov-file)"
beyond just faking a user agents, it is able to scrape *vastly* more sites than a
default-configured HTTP client like HTTPoison, Finch,
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

Because of its reliability, price (free!), and low resource consumption,
Browsey makes a better *first* choice for your scraping needs. Then you can fall back to
expensive third-party APIs when you encounter a site that really needs a headless browser.

## Installation

1. Add BrowseyHttp to your deps, and ensure either `:exec` or `:dockerexec` is installed as well:

    ```elixir
    defp deps do
    [
      {:browsey_http, github: "s3cur3/browsey_http", branch: "main"},
      # Optional: you may already be using erlexec in your app. If you're not,
      # you'll need to either install it, or dockerexec (which is less fussy when
      # deployed in Docker environments).
      {:dockerexec, "~> 2.0"},
    ]
    ```

2. Run `$ mix setup` or `$ mix deps.get` to download the new dependency

## Usage

Once installed, you can scrape a single page using [`BrowseyHttp.get/2`](http://hexdocs.codecodeship.com/browsey_http/0.0.7/BrowseyHttp.html#get/2):

```elixir
case BrowseyHttp.get("https://www.example.com") do
  {:ok, %BrowseyHttp.Response{} = response} -> handle_response(response)
  {:error, exception} -> handle_error(exception)
end
```

Or you can download a page *plus* all the resources it embeds (images, CSS, JavaScript) 
in parallel using [`BrowseyHttp.get_with_resources/2`](http://hexdocs.codecodeship.com/browsey_http/0.0.7/BrowseyHttp.html#get_with_resources/2):

```elixir
case BrowseyHttp.get_with_resources("https://www.example.com") do
  {:ok, [%BrowseyHttp.Response{} = primary_response | resource_responses]} ->
    handle_response(response)
    handle_resources(resource_responses)

  {:error, exception} ->
    handle_error(exception)
end
```

You can also get the additional resources as a [Stream](https://hexdocs.pm/elixir/Stream.html)
via [`BrowseyHttp.stream_with_resources/2`](http://hexdocs.codecodeship.com/browsey_http/0.0.7/BrowseyHttp.html#stream_with_resources/2).

See the docs linked above for a breakdown of the available options to these functions.
