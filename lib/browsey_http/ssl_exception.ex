defmodule BrowseyHttp.SslException do
  @moduledoc false
  defexception [:message, :uri]

  @type t() :: %__MODULE__{message: String.t(), uri: URI.t()}

  @spec new(URI.t()) :: t()
  def new(%URI{} = uri) do
    %__MODULE__{message: "SSL/TLS handshake failed", uri: uri}
  end
end
