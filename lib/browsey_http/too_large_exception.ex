defmodule BrowseyHttp.TooLargeException do
  @moduledoc false
  defexception [:message, :uri]

  def content_length_exceeded(bytes, max_bytes, %URI{} = uri) do
    %__MODULE__{message: "Content-Length #{bytes} exceeds #{format_bytes(max_bytes)}", uri: uri}
  end

  def response_body_exceeds_bytes(bytes, %URI{} = uri) do
    %__MODULE__{message: "Response body exceeds #{format_bytes(bytes)}", uri: uri}
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
