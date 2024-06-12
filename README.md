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

## Installation

1. [Buy a license for BrowseyHttp](https://hex.codecodeship.com/package/browsey_http)
2. Add CodeCodeShip as a new Hex repo so that you'll be able to download the dependency.
    I recommend adding this as a new Mix task so you can include it in your `mix setup` process.
    Here's what that looks like in your `mix.exs` file (note that you'll need to replace `YOUR-AUTH-KEY-HERE` with the license key CodeCodeShip provides):

    ```elixir
    defp aliases do
    [
      ...,
      "setup.deps": [
          "hex.repo add codecodeship https://hex.codecodeship.com/api/repo --fetch-public-key SHA256:5hyUvvnGT45CntYCrHAOO3tn94l1xz8fUlyQS7qDhxg --auth-key YOUR-AUTH-KEY-HERE"
        ]
      # Add setup.deps as the first step in whatever your existing setup process was
      setup: ["setup.deps", "deps.get", "ecto.setup", "assets.setup", "assets.build"],
      ...
    ]
    ```
3. Add it to your `mix.exs` file's dependencies:

    ```elixir
    def deps do
      [
        {:browsey_http, "~> 0.0.5", repo: :codecodeship},
        # Optional: you may already be using erlexec in your app. If you're not,
        # you'll need to either install it, or dockerexec (which is less fussy when
        # deployed in Docker environments).
        {:dockerexec, "~> 2.0"},
      ]
    end
    ```
4. Run `$ mix setup` to both add the CodeCodeship repo and download the new dependency.

If you use GitHub Dependabot, you'll need to update your Dependabot configuration 
with the CodeCodeShip repo as in the sample below. Don't forget to also add the
public and private keys to your Dependabot secrets in the repo settings.

```yaml
version: 2
updates:
- package-ecosystem: mix
  schedule:
    interval: weekly
  registries:
  - 'codecodeship'
  # Required for Dependabot to run external repository code
  insecure-external-code-execution: allow
registries:
   codecodeship:
     type: hex-repository
     repo: codecodeship
     url: https://hex.codecodeship.com/api/repo
     auth-key: ${{ secrets.BROWSEY_AUTH_KEY }}
     public-key-fingerprint: ${{ secrets.BROWSEY_PUBLIC_KEY }}
```

## Usage

Once installed, you can scrape a single page using [`BrowseyHttp.get/2`](http://hexdocs.codecodeship.com/browsey_http/0.0.5/BrowseyHttp.html#get/2):

```elixir
case BrowseyHttp.get("https://www.example.com") do
  {:ok, %BrowseyHttp.Response{} = response} -> handle_response(response)
  {:error, exception} -> handle_error(exception)
end
```

Or you can download a page *plus* all the resources it embeds (images, CSS, JavaScript) 
in parallel using [`BrowseyHttp.get_with_resources/2`](http://hexdocs.codecodeship.com/browsey_http/0.0.5/BrowseyHttp.html#get_with_resources/2):

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
via [`BrowseyHttp.stream_with_resources/2`](http://hexdocs.codecodeship.com/browsey_http/0.0.5/BrowseyHttp.html#stream_with_resources/2).

See the docs linked above for a breakdown of the available options to these functions.
