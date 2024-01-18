defmodule BrowseyHttp.Html do
  @moduledoc false

  @type include_opt ::
          {:fetch_images?, boolean()}
          | {:fetch_css?, boolean()}
          | {:fetch_js?, boolean()}

  @spec urls_a_browser_would_load_immediately(Floki.html_tree(), [include_opt]) :: [String.t()]
  def urls_a_browser_would_load_immediately(document, opts) do
    image_srcs =
      if opts[:fetch_images?] != false do
        Floki.attribute(document, "img[src]", "src")
      else
        []
      end

    js_srcs =
      if opts[:fetch_js?] != false do
        Floki.attribute(document, "script[src]", "src")
      else
        []
      end

    stylesheets =
      if opts[:fetch_css?] != false do
        Floki.attribute(document, "link[rel='stylesheet']", "href")
      else
        []
      end

    (image_srcs ++ js_srcs ++ stylesheets)
    |> Enum.uniq()
    |> Enum.filter(&valid_link?/1)
  end

  @doc """
  True if this is a valid reference to another document or non-embedded resource.
  """
  def valid_link?("#"), do: false
  # Occurs when you have just <a href> with no value
  def valid_link?("href"), do: false
  def valid_link?("data:" <> _), do: false
  def valid_link?("blob:" <> _), do: false
  def valid_link?(url) when byte_size(url) > 0, do: true
  def valid_link?(_), do: false
end
