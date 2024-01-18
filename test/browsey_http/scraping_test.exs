defmodule BrowseyHttp.ScrapingTest do
  use ExUnit.Case, async: true

  doctest BrowseyHttp

  @tag scraping_todo: true
  test "scrapes Twitter" do
    url = "https://twitter.com/FaizaanShamsi/status/1747641905981100212"

    page_text =
      url
      |> get_body!()
      |> Floki.parse_document!()
      |> Floki.text()

    assert page_text =~ "could you please send a resume"
  end

  @tag scraping_todo: true
  test "scrapes Instagram" do
    assert scrape_text("https://www.instagram.com/reel/C2AT5H1uNBw/?igsh=MXZlMTc0eXFmaDc3cQ==") =~
             "Admit it, you'd be down!"
  end

  @tag local_integration: true
  test "scrapes SleepEasy (protected by Cloudflare)" do
    assert scrape_text("https://www.sleepeasy.app") =~ "Proactive website monitoring"
  end

  @tag local_integration: true
  test "scrapes Google Sites" do
    assert scrape_text("https://www.thegiftedguide.com") =~ "The Gifted Guide"
  end

  @tag local_integration: true
  test "scrapes AllTrails" do
    # AllTrails uses DataDome for bot protection:
    # https://datadome.co/customers-stories/alltrails-secures-its-mobile-apps-website-and-api-from-bad-bots-with-datadome/
    assert scrape_text("https://www.alltrails.com/trail/us/missouri/stocksdale-park") =~
             "Explore this 3.0-mile loop"
  end

  @tag local_integration: true
  test "scrapes RealClearPolitics" do
    # DataDome customer: https://datadome.co/customers-stories/realclearpolitics-filters-invalid-traffic/
    url =
      "https://www.realclearpolitics.com/articles/2024/01/17/nikki_haley_has_seven_weeks_to_flip_the_script_150334.html"

    assert scrape_text(url) =~ "Nikki Haley Has Seven Weeks To Flip the Script"
  end

  @tag local_integration: true
  test "scrapes Patreon" do
    # DataDome customer: https://datadome.co/customers-stories/patreon-defends-users-against-ato-scraping-ddos-attacks/
    assert scrape_text("https://www.patreon.com/Rossdraws") =~ "Choose your membership"
  end

  @tag local_integration: true
  test "scrapes Reddit" do
    # DataDome customer: https://datadome.co/customers-stories/reddit-traffic-classification-accurate-billing/
    url =
      "https://www.reddit.com/r/rush/comments/199b15n/quickwhat_was_the_last_rush_song_you_listened_to/"

    assert scrape_text(url) =~ "Quick....what was the last Rush song you listened to...."
  end

  @tag local_integration: true
  test "scrapes Zillow" do
    url = "https://www.zillow.com/homedetails/Crockett-Rd-Liberty-MO-64068/2054947918_zpid/"
    assert scrape_text(url) =~ "Crockett Rd, Liberty, MO"
  end

  @tag local_integration: true
  test "scrapes Realtor.com" do
    url =
      "https://www.realtor.com/realestateandhomes-detail/11409-Meadow-Ln_Leawood_KS_66211_M86302-48887"

    assert scrape_text(url) =~ "11409 Meadow Ln, Leawood"
  end

  @tag local_integration: true
  test "scrapes Trulia" do
    url = "https://www.trulia.com/home/2858-briarcliff-rd-atlanta-ga-30329-14543068"
    assert scrape_text(url) =~ "2858 Briarcliff Rd"
  end

  defp scrape_text(url) do
    url
    |> get_body!()
    |> Floki.parse_document!()
    |> Floki.text()
  end

  defp get_body!(url) do
    %BrowseyHttp.Response{body: body} = BrowseyHttp.get!(url)
    body
  end
end
