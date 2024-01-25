defmodule BrowseyHttp.TimeoutExceptionTest do
  use ExUnit.Case, async: true

  alias BrowseyHttp.TimeoutException

  @uri URI.parse("https://example.com")

  test "formats milliseconds" do
    exception = TimeoutException.timed_out(@uri, 999)
    assert exception.timeout_ms == 999
    assert exception.uri == @uri
    assert exception.message == "Timed out after 999 milliseconds"
  end

  test "formats single second" do
    exception = TimeoutException.timed_out(@uri, 1000)
    assert exception.timeout_ms == 1000
    assert exception.uri == @uri
    assert exception.message == "Timed out after 1 second"
  end

  test "formats seconds" do
    exception = TimeoutException.timed_out(@uri, 1100)
    assert exception.timeout_ms == 1100
    assert exception.uri == @uri
    assert exception.message == "Timed out after 1.1 seconds"

    exception = TimeoutException.timed_out(@uri, 5000)
    assert exception.timeout_ms == 5000
    assert exception.uri == @uri
    assert exception.message == "Timed out after 5.0 seconds"

    exception = TimeoutException.timed_out(@uri, 5001)
    assert exception.timeout_ms == 5001
    assert exception.uri == @uri
    assert exception.message == "Timed out after 5.001 seconds"
  end

  test "formats infinity" do
    exception = TimeoutException.timed_out(@uri, :infinity)
    assert exception.timeout_ms == :infinity
    assert exception.uri == @uri
    assert exception.message == "Timed out"
  end
end
