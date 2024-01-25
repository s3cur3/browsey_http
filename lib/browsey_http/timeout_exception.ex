defmodule BrowseyHttp.TimeoutException do
  @moduledoc false
  defexception [:message, :uri, :timeout_ms]

  @type t() :: %__MODULE__{
          message: String.t(),
          uri: URI.t(),
          timeout_ms: timeout()
        }

  @spec timed_out(URI.t(), timeout()) :: t()
  def timed_out(%URI{} = uri, :infinity) do
    %__MODULE__{message: "Timed out", uri: uri, timeout_ms: :infinity}
  end

  def timed_out(%URI{} = uri, max_ms) do
    %__MODULE__{message: format_msg(max_ms), uri: uri, timeout_ms: max_ms}
  end

  defp format_msg(max_ms) when max_ms < 1_000, do: "Timed out after #{max_ms} milliseconds"
  defp format_msg(1000), do: "Timed out after 1 second"
  defp format_msg(max_ms), do: "Timed out after #{max_ms / 1_000} seconds"
end
