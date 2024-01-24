defmodule BrowseyHttp.SslException do
  @moduledoc false
  defexception [:message, :uri]

  def new(%URI{} = uri) do
    %__MODULE__{message: "SSL/TLS handshake failed", uri: uri}
  end
end
