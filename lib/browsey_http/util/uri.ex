defmodule BrowseyHttp.Util.Uri do
  @moduledoc false

  def canonical_uri("http://" <> _ = url, _), do: URI.parse(url)
  def canonical_uri("https://" <> _ = url, _), do: URI.parse(url)

  def canonical_uri("//" <> protocol_relative, %URI{scheme: scheme}) do
    URI.parse(scheme <> "://" <> protocol_relative)
  end

  def canonical_uri("/" <> _ = abs, %URI{} = relative_to) do
    URI.merge(relative_to, abs)
  end

  def canonical_uri(relative_path, %URI{} = relative_to) do
    URI.merge(relative_to, relative_path)
  end
end
