defmodule BrowseyHttp.Util.Uri do
  @moduledoc false

  @spec host_without_subdomains(URI.t()) :: String.t() | nil
  def host_without_subdomains(%URI{host: host}) when byte_size(host) > 0 do
    case Domainatrex.parse(host) do
      {:ok, %{domain: domain, tld: tld}} when byte_size(domain) > 0 and byte_size(tld) > 0 ->
        "#{domain}.#{tld}"

      _ ->
        host
    end
  end

  def host_without_subdomains(_), do: nil

  @spec canonical_uri(String.t(), URI.t()) :: URI.t()
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
