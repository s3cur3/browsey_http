defmodule BrowseyHttp.TooLargeExceptionTest do
  use ExUnit.Case, async: true

  alias BrowseyHttp.TooLargeException

  @uri URI.parse("https://example.com")

  test "formats bytes" do
    exception = TooLargeException.new(@uri, 1024)
    assert exception.max_bytes == 1024
    assert exception.uri == @uri
    assert exception.message == "Response body exceeds 1024 bytes"
  end

  test "formats large byte sizes" do
    bytes = 123_456_789
    exception = TooLargeException.new(@uri, bytes)
    assert exception.max_bytes == bytes
    assert exception.uri == @uri
    assert exception.message == "Response body exceeds #{bytes} bytes"
  end

  test "formats exact megabyte sizes" do
    bytes_per_mb = 1024 * 1024

    for megabytes <- 0..5 do
      bytes = megabytes * bytes_per_mb
      exception = TooLargeException.new(@uri, bytes)
      assert exception.max_bytes == bytes
      assert exception.uri == @uri
      assert exception.message == "Response body exceeds #{megabytes} MB"
    end
  end
end
