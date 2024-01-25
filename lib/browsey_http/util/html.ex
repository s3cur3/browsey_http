defmodule BrowseyHttp.Util.Html do
  @moduledoc false

  @type include_opt ::
          {:fetch_images?, as_boolean(term)}
          | {:fetch_css?, as_boolean(term)}
          | {:fetch_js?, as_boolean(term)}

  @spec urls_a_browser_would_load_immediately(Floki.html_tree(), [include_opt]) :: [String.t()]
  def urls_a_browser_would_load_immediately(document, opts) do
    image_srcs =
      if Access.get(opts, :fetch_images?, true) do
        named_icons =
          Enum.concat([
            Floki.attribute(document, "link[rel*='icon']", "href"),
            Floki.attribute(document, "link[rel*='apple-touch-icon']", "href"),
            Floki.attribute(document, "link[rel*='apple-touch-icon-precomposed']", "href")
          ])

        Enum.concat([
          Floki.attribute(document, "meta[property='og:image']", "content"),
          if Enum.empty?(named_icons) do
            ["/favicon.ico"]
          else
            named_icons
          end,
          Floki.attribute(document, "img[src]", "src")
        ])
      else
        []
      end

    js_srcs =
      if Access.get(opts, :fetch_js?, true) do
        Floki.attribute(document, "script[src]", "src")
      else
        []
      end

    stylesheets =
      if Access.get(opts, :fetch_css?, true) do
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
  @spec valid_link?(String.t()) :: boolean
  def valid_link?("#"), do: false
  # Occurs when you have just <a href> with no value
  def valid_link?("href"), do: false
  def valid_link?("data:" <> _), do: false
  def valid_link?("blob:" <> _), do: false
  def valid_link?(url) when byte_size(url) > 0, do: true
  def valid_link?(_), do: false
end
