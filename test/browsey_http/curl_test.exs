defmodule BrowseyHttp.CurlTest do
  use ExUnit.Case, async: true

  alias BrowseyHttp.Curl

  test "processes headers" do
    stderr_output = """
      % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                     Dload  Upload   Total   Spent    Left  Speed
      0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 127.0.0.1:59554...
    * Connected to localhost (127.0.0.1) port 59554 (#0)
    > GET / HTTP/1.1
    > Host: localhost:59554
    > Connection: Upgrade, HTTP2-Settings
    > Upgrade: h2c
    > HTTP2-Settings: AAEAAQAAAAIAAAAAAAMAAAPoAAQAYAAAAAYABAAA
    > Accept-Language: en-US,en;q=0.9
    > 
    < HTTP/1.1 101 Switching Protocols
    < connection: Upgrade
    < upgrade: h2c
    * Received 101, Switching to HTTP/2
    * Copied HTTP/2 data in stream buffer to connection buffer after upgrade: len=9
    < HTTP/2 401 
    < cache-control: max-age=0, private, must-revalidate
    < content-length: 2
    < content-type: not/real
    < date: Wed, 24 Jan 2024 18:12:35 GMT
    < foo: bar: baz
    < server: Cowboy
    < 
    { [2 bytes data]
    100     2  100     2    0     0     56      0 --:--:-- --:--:-- --:--:--    60
    * Connection #0 to host localhost left intact
    """

    assert %{headers: headers, status: status} = Curl.parse_metadata(stderr_output)

    assert headers == %{
             "cache-control" => ["max-age=0, private, must-revalidate"],
             "content-length" => ["2"],
             "content-type" => ["not/real"],
             "date" => ["Wed, 24 Jan 2024 18:12:35 GMT"],
             "foo" => ["bar: baz"],
             "server" => ["Cowboy"]
           }

    assert status == 401
  end

  test "parses redirects" do
    stderr_output = """
      % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
    0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 127.0.0.1:59752...
    * Connected to localhost (127.0.0.1) port 59752 (#0)
    > GET / HTTP/1.1
    > Host: localhost:59752
    > Connection: Upgrade, HTTP2-Settings
    > Upgrade: h2c
    > HTTP2-Settings: AAEAAQAAAAIAAAAAAAMAAAPoAAQAYAAAAAYABAAA
    > sec-ch-ua: "Chromium";v="116", "Not)A;Brand";v="24", "Google Chrome";v="116"
    > sec-ch-ua-mobile: ?0
    > sec-ch-ua-platform: "Windows"
    > Upgrade-Insecure-Requests: 1
    > User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36
    > Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
    > Sec-Fetch-Site: none
    > Sec-Fetch-Mode: navigate
    > Sec-Fetch-User: ?1
    > Sec-Fetch-Dest: document
    > Accept-Encoding: gzip, deflate, br
    > Accept-Language: en-US,en;q=0.9
    > 
    < HTTP/1.1 101 Switching Protocols
    < connection: Upgrade
    < upgrade: h2c
    * Received 101, Switching to HTTP/2
    * Copied HTTP/2 data in stream buffer to connection buffer after upgrade: len=9
    < HTTP/2 301 
    < cache-control: max-age=0, private, must-revalidate
    < content-length: 11
    < date: Wed, 24 Jan 2024 18:38:47 GMT
    < location: /target1
    < server: Cowboy
    < 
    * Ignoring the response-body
    { [11 bytes data]
    100    11  100    11    0     0    346      0 --:--:-- --:--:-- --:--:--   366
    * Connection #0 to host localhost left intact
    * Issue another request to this URL: 'http://localhost:59752/target1'
    * Found bundle for host: 0x149f05490 [can multiplex]
    * Re-using existing connection #0 with host localhost
    * h2 [:method: GET]
    * h2 [:authority: localhost:59752]
    * h2 [:scheme: http]
    * h2 [:path: /target1]
    * h2 [sec-ch-ua: "Chromium";v="116", "Not)A;Brand";v="24", "Google Chrome";v="116"]
    * h2 [sec-ch-ua-mobile: ?0]
    * h2 [sec-ch-ua-platform: "Windows"]
    * h2 [upgrade-insecure-requests: 1]
    * h2 [user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36]
    * h2 [accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7]
    * h2 [sec-fetch-site: none]
    * h2 [sec-fetch-mode: navigate]
    * h2 [sec-fetch-user: ?1]
    * h2 [sec-fetch-dest: document]
    * h2 [accept-encoding: gzip, deflate, br]
    * h2 [accept-language: en-US,en;q=0.9]
    * Using Stream ID: 3 (easy handle 0x14a80a800)
    > GET /target1 HTTP/2
    > Host: localhost:59752
    > sec-ch-ua: "Chromium";v="116", "Not)A;Brand";v="24", "Google Chrome";v="116"
    > sec-ch-ua-mobile: ?0
    > sec-ch-ua-platform: "Windows"
    > Upgrade-Insecure-Requests: 1
    > User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36
    > Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
    > Sec-Fetch-Site: none
    > Sec-Fetch-Mode: navigate
    > Sec-Fetch-User: ?1
    > Sec-Fetch-Dest: document
    > Accept-Encoding: gzip, deflate, br
    > Accept-Language: en-US,en;q=0.9
    > 
    < HTTP/2 301 
    < cache-control: max-age=0, private, must-revalidate
    < content-length: 17
    < date: Wed, 24 Jan 2024 18:38:47 GMT
    < location: /target2
    < server: Cowboy
    < 
    * Ignoring the response-body
    { [17 bytes data]
    100    17  100    17    0     0    526      0 --:--:-- --:--:-- --:--:--   526
    * Connection #0 to host localhost left intact
    * Issue another request to this URL: 'http://localhost:59752/target2'
    * Found bundle for host: 0x149f05490 [can multiplex]
    * Re-using existing connection #0 with host localhost
    * h2 [:method: GET]
    * h2 [:authority: localhost:59752]
    * h2 [:scheme: http]
    * h2 [:path: /target2]
    * h2 [sec-ch-ua: "Chromium";v="116", "Not)A;Brand";v="24", "Google Chrome";v="116"]
    * h2 [sec-ch-ua-mobile: ?0]
    * h2 [sec-ch-ua-platform: "Windows"]
    * h2 [upgrade-insecure-requests: 1]
    * h2 [user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36]
    * h2 [accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7]
    * h2 [sec-fetch-site: none]
    * h2 [sec-fetch-mode: navigate]
    * h2 [sec-fetch-user: ?1]
    * h2 [sec-fetch-dest: document]
    * h2 [accept-encoding: gzip, deflate, br]
    * h2 [accept-language: en-US,en;q=0.9]
    * Using Stream ID: 5 (easy handle 0x14a80a800)
    > GET /target2 HTTP/2
    > Host: localhost:59752
    > sec-ch-ua: "Chromium";v="116", "Not)A;Brand";v="24", "Google Chrome";v="116"
    > Accept-Language: en-US,en;q=0.9
    > 
    < HTTP/2 200 
    < cache-control: max-age=0, private, must-revalidate
    < content-length: 22
    < date: Wed, 24 Jan 2024 18:38:47 GMT
    < server: Cowboy
    < set-cookie: foo=bar
    < set-cookie: bip=bop
    < 
    { [22 bytes data]
    100    22  100    22    0     0    675      0 --:--:-- --:--:-- --:--:--   675
    * Connection #0 to host localhost left intact
    """

    assert %{headers: headers, paths: paths} = Curl.parse_metadata(stderr_output)

    assert headers == %{
             "cache-control" => ["max-age=0, private, must-revalidate"],
             "content-length" => ["22"],
             "date" => ["Wed, 24 Jan 2024 18:38:47 GMT"],
             "server" => ["Cowboy"],
             "set-cookie" => ["foo=bar", "bip=bop"]
           }

    assert paths == ["/", "/target1", "/target2"]
  end
end
