defmodule BrowseyHttp.TooLargeException do
  @moduledoc false
  defexception [:message, :uri, :max_bytes]

  def new(%URI{} = uri, bytes) do
    %__MODULE__{
      message: "Response body exceeds #{format_bytes(bytes)}",
      uri: uri,
      max_bytes: bytes
    }
  end

  defp format_bytes(bytes) do
    bytes_to_mb = 1024 * 1024

    if rem(bytes, bytes_to_mb) == 0 do
      mb = div(bytes, bytes_to_mb)
      "#{mb} MB"
    else
      "#{bytes} bytes"
    end
  end
end
