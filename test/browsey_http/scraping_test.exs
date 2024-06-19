defmodule BrowseyHttp.ScrapingTest do
  use ExUnit.Case, async: true

  import ExampleTest

  doctest BrowseyHttp

  setup do
    Process.sleep(3_000)
  end

  @moduletag local_integration: true

  example_test "scrapes real-world pages",
               """
               | site_name          | expected_text                           | url                                                              |
               |--------------------|-----------------------------------------|------------------------------------------------------------------|
               | "SleepEasy"        | "Proactive website monitoring"          | "https://www.sleepeasy.app"                                      |
               | "Google Sites"     | "The Gifted Guide"                      | "https://www.thegiftedguide.com"                                 |
               | "AllTrails"        | "Explore this 3.0-mile loop"            | "https://www.alltrails.com/trail/us/missouri/stocksdale-park"    |
               """,
               %{expected_text: expected_text, url: url} do
    assert scrape_text(url) =~ expected_text
  end

  example_test "scrapes DataDome sites",
               """
               | site_name             | expected_text                                     | url                                                              |
               |-----------------------|---------------------------------------------------|------------------------------------------------------------------|
               | "AllTrails"           | "Explore this 3.0-mile loop"                      | "https://www.alltrails.com/trail/us/missouri/stocksdale-park"    |
               | "RealClearPolitics"   | "Nikki Haley Has Seven Weeks To Flip the Script"  | "https://www.realclearpolitics.com/articles/2024/01/17/nikki_haley_has_seven_weeks_to_flip_the_script_150334.html" |
               | "Patreon"             | "Choose your membership"                          | "https://www.patreon.com/Rossdraws"                              |
               | "Reddit"              | "Quick....what was the last Rush song"            | "https://www.reddit.com/r/rush/comments/199b15n/quickwhat_was_the_last_rush_song_you_listened_to/" |
               """,
               %{expected_text: expected_text, url: url} do
    assert scrape_text(url) =~ expected_text
  end

  test "scrapes Twitter" do
    url = "https://x.com/FaizaanShamsi/status/1747641905981100212"

    page_text =
      url
      |> get_body!()
      |> Floki.parse_document!()
      |> Floki.raw_html()

    assert page_text =~ "could you please send a resume"
  end

  @tag scraping_todo: true
  test "scrapes Instagram" do
    assert scrape_text("https://www.instagram.com/reel/C2AT5H1uNBw/?igsh=MXZlMTc0eXFmaDc3cQ==") =~
             "Admit it, you'd be down!"
  end

  @tag local_integration: true
  test "scrapes Zillow" do
    url = "https://www.zillow.com/homedetails/Crockett-Rd-Liberty-MO-64068/2054947918_zpid/"
    assert scrape_text(url) =~ "Crockett Rd, Liberty, MO"
  end

  @tag local_integration: true
  test "scrapes Trulia" do
    url = "https://www.trulia.com/home/2858-briarcliff-rd-atlanta-ga-30329-14543068"
    assert scrape_text(url) =~ "2858 Briarcliff Rd"
  end

  describe "sites protected by PerimeterX/HUMAN security" do
    @tag local_integration: true
    test "scrapes Realtor.com" do
      url =
        "https://www.realtor.com/realestateandhomes-detail/11409-Meadow-Ln_Leawood_KS_66211_M86302-48887"

      assert scrape_text(url) =~ "11409 Meadow Ln, Leawood"
    end

    @tag local_integration: true
    test "scrapes Sweetwater.com" do
      url = "https://www.sweetwater.com/shop/guitars/electric-guitars/"
      assert scrape_text(url) =~ "Electric Guitars Buying Guide"
    end

    @tag local_integration: true
    test "scrapes Build.com" do
      url = "https://www.build.com"
      assert scrape_text(url) =~ "Shop All Departments"
    end
  end

  @tag local_integration: true
  test "scrapes Udemy" do
    url = "https://www.udemy.com/course/the-complete-web-development-bootcamp/"
    assert scrape_text(url) =~ "Welcome to the Complete Web Development Bootcamp"
  end

  @tag local_integration: true
  test "scrapes OpenSea" do
    url = "https://opensea.io/rankings/trending"
    assert scrape_text(url) =~ "Collection stats"
  end

  @tag local_integration: true
  test "scrapes TicketMaster" do
    url = "https://www.ticketmaster.com/disney-on-ice-presents-into-the-tickets/artist/2374998"
    text = scrape_text(url)
    assert text =~ "Reviews ("
    assert text =~ "Disney On Ice presents Into the Magic Tickets"
  end

  @tag local_integration: true
  test "scrapes Google" do
    url = "https://www.google.com/search?q=testing"
    text = scrape_text(url)
    assert text =~ "www.testing.com"
  end

  @tag local_integration: true
  test "scrapes LinkedIn" do
    url = "https://www.linkedin.com/in/bruce-tate"
    text = scrape_text(url)
    assert text =~ "Bruce Tate"
    assert text =~ "Chattanooga, Tennessee"
    assert text =~ "Experience & Education"
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
