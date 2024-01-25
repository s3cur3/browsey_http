defmodule BrowseyHttp.Util.CurlTest do
  use ExUnit.Case, async: true

  alias BrowseyHttp.Util.Curl

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

    uri = URI.parse("http://localhost:59752")
    assert %{headers: headers, status: status} = Curl.parse_metadata(stderr_output, uri)

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

  test "copes with missing status" do
    stderr_output = """
      % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                     Dload  Upload   Total   Spent    Left  Speed
      0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 127.0.0.1:59554...
    * Connected to localhost (127.0.0.1) port 59554 (#0)
    < HTTP/1.1 101 Switching Protocols
    < connection: Upgrade
    < upgrade: h2c
    < HTTP/2 noninteger!
    < foo: bar: baz
    < server: Cowboy
    * Connection #0 to host localhost left intact
    """

    uri = URI.parse("http://localhost:59752")
    assert %{headers: headers, status: status} = Curl.parse_metadata(stderr_output, uri)

    assert headers == %{
             "foo" => ["bar: baz"],
             "server" => ["Cowboy"]
           }

    assert is_nil(status)
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

    root_uri = URI.parse("http://localhost:59752")
    assert %{headers: headers, uris: uris} = Curl.parse_metadata(stderr_output, root_uri)

    assert headers == %{
             "cache-control" => ["max-age=0, private, must-revalidate"],
             "content-length" => ["22"],
             "date" => ["Wed, 24 Jan 2024 18:38:47 GMT"],
             "server" => ["Cowboy"],
             "set-cookie" => ["foo=bar", "bip=bop"]
           }

    assert uris == Enum.map(["/", "/target1", "/target2"], &%{root_uri | path: &1})
  end

  test "parses redirect to HTTPS" do
    stderr_output = """
      % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
    0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 54.84.236.175:80...
    * Connected to tylerayoung.com (54.84.236.175) port 80 (#0)
    > GET / HTTP/1.1
    > Host: tylerayoung.com
    > Accept-Encoding: gzip, deflate, br
    > Accept-Language: en-US,en;q=0.9
    > 
    < HTTP/1.1 301 Moved Permanently
    < Content-Type: text/plain; charset=utf-8
    < Date: Thu, 25 Jan 2024 19:27:56 GMT
    < Location: https://tylerayoung.com/
    < Server: Netlify
    < X-Nf-Request-Id: 01HN11FPYX5KJTV1RQ91EP9EXQ
    < Content-Length: 39
    < 
    * Ignoring the response-body
    { [39 bytes data]
    100    39  100    39    0     0    379      0 --:--:-- --:--:-- --:--:--   386
    * Connection #0 to host tylerayoung.com left intact
    * Clear auth, redirects to port from 80 to 443
    * SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
    * ALPN: server accepted h2
    * Server certificate:
    *  subject: CN=*.tylerayoung.com
    *  SSL certificate verify ok.
    { [5 bytes data]
    * TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
    { [122 bytes data]
    * using HTTP/2
    * h2 [:method: GET]
    } [5 bytes data]
    > GET / HTTP/2
    > Host: tylerayoung.com
    > sec-ch-ua: "Chromium";v="116", "Not)A;Brand";v="24", "Google Chrome";v="116"
    > Accept-Language: en-US,en;q=0.9
    > 
    { [5 bytes data]
    < HTTP/2 200 
    < accept-ranges: bytes
    < age: 203
    < cache-control: public,max-age=0,must-revalidate
    < x-nf-request-id: 01HN11FQ28PSS4E7BQDCHWC4FF
    < content-length: 13963
    < 
    { [4096 bytes data]
    100 13963  100 13963    0     0  56969      0 --:--:-- --:--:-- --:--:-- 56969
    * Connection #1 to host tylerayoung.com left intact
    """

    uri = URI.parse("http://tylerayoung.com")
    assert %{uris: uris, status: 200} = Curl.parse_metadata(stderr_output, uri)

    assert uris == [%{uri | path: "/"}, URI.parse("https://tylerayoung.com/")]
  end

  test "parses redirect to HTTPS + WWW" do
    stderr_output = """
      % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
    0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 216.40.34.41:80...
    * Connected to thegiftedguide.com (216.40.34.41) port 80 (#0)
    > GET / HTTP/1.1
    > Host: thegiftedguide.com
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
    < HTTP/1.1 303 See Other
    < server: nginx/1.14.2
    < date: Thu, 25 Jan 2024 20:29:29 GMT
    < content-type: text/html; charset=utf-8
    < transfer-encoding: chunked
    < x-frame-options: SAMEORIGIN
    < x-xss-protection: 1; mode=block
    < x-content-type-options: nosniff
    < x-download-options: noopen
    < x-permitted-cross-domain-policies: none
    < referrer-policy: strict-origin-when-cross-origin
    < location: https://www.thegiftedguide.com
    < cache-control: no-cache
    < x-request-id: b8e18d8d-32b9-4a9e-a45c-33dedc4ea18b
    < x-runtime: 0.010037
    < 
    * Ignoring the response-body
    { [107 bytes data]
    100    96    0    96    0     0    754      0 --:--:-- --:--:-- --:--:--   774
    * Connection #0 to host thegiftedguide.com left intact
    * Clear auth, redirects to port from 80 to 443
    * Issue another request to this URL: 'https://www.thegiftedguide.com/'
    *   Trying 142.250.114.121:443...
    * Connected to www.thegiftedguide.com (142.250.114.121) port 443 (#1)
    * SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
    * ALPN: server accepted h2
    * Server certificate:
    *  subject: CN=www.thegiftedguide.com
    *  start date: Jan  2 14:14:21 2024 GMT
    *  expire date: Apr  1 15:04:12 2024 GMT
    *  subjectAltName: host "www.thegiftedguide.com" matched cert's "www.thegiftedguide.com"
    *  issuer: C=US; O=Google Trust Services LLC; CN=GTS CA 1D4
    *  SSL certificate verify ok.
    } [5 bytes data]
    * using HTTP/2
    * h2 [:method: GET]
    * h2 [:authority: www.thegiftedguide.com]
    * h2 [:scheme: https]
    * h2 [:path: /]
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
    * Using Stream ID: 1 (easy handle 0x7f9e2000a800)
    } [5 bytes data]
    > GET / HTTP/2
    > Host: www.thegiftedguide.com
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
    { [5 bytes data]
    < HTTP/2 200 
    < content-type: text/html; charset=utf-8
    < x-frame-options: DENY
    < vary: Sec-Fetch-Dest, Sec-Fetch-Mode, Sec-Fetch-Site
    < cache-control: no-cache, no-store, max-age=0, must-revalidate
    < pragma: no-cache
    < expires: Mon, 01 Jan 1990 00:00:00 GMT
    < date: Thu, 25 Jan 2024 20:29:30 GMT
    < content-security-policy: base-uri 'self';object-src 'none';report-uri /_/view/cspreport;script-src 'report-sample' 'nonce-ZBTwXu3V9j5RSysGcYxsGg' 'unsafe-inline' 'unsafe-eval';worker-src 'self';frame-ancestors https://google-admin.corp.google.com/
    < cross-origin-resource-policy: same-site
    < cross-origin-opener-policy: unsafe-none
    < referrer-policy: strict-origin-when-cross-origin
    < server: ESF
    < x-xss-protection: 0
    < x-content-type-options: nosniff
    < content-encoding: gzip
    < 
    { [230 bytes data]
    100 15139    0 15139    0     0  46783      0 --:--:-- --:--:-- --:--:-- 46783
    * Connection #1 to host www.thegiftedguide.com left intact
    """

    uri = URI.parse("http://thegiftedguide.com")
    assert %{uris: uris, status: 200} = Curl.parse_metadata(stderr_output, uri)

    assert uris == [%{uri | path: "/"}, URI.parse("https://www.thegiftedguide.com/")]
  end

  test "handles Trulia response" do
    stderr_output = """
          % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                     Dload  Upload   Total   Spent    Left  Speed
      0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 3.161.225.77:443...
    * Connected to www.trulia.com (3.161.225.77) port 443 (#0)
    * ALPN: offers h2,http/1.1
    * Cipher selection: TLS_AES_128_GCM_SHA256,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,ECDHE-ECDSA-AES128-GCM-SHA256,ECDHE-RSA-AES128-GCM-SHA256,ECDHE-ECDSA-AES256-GCM-SHA384,ECDHE-RSA-AES256-GCM-SHA384,ECDHE-ECDSA-CHACHA20-POLY1305,ECDHE-RSA-CHACHA20-POLY1305,ECDHE-RSA-AES128-SHA,ECDHE-RSA-AES256-SHA,AES128-GCM-SHA256,AES256-GCM-SHA384,AES128-SHA,AES256-SHA
    * ALPS: offers h2
    } [5 bytes data]
    * TLSv1.2 (OUT), TLS handshake, Client hello (1):
    } [36 bytes data]
    * SSL connection using TLSv1.3 / TLS_AES_128_GCM_SHA256
    * ALPN: server accepted h2
    * Server certificate:
    *  subject: CN=trulia.com
    *  start date: May  4 00:00:00 2023 GMT
    *  expire date: Jun  1 23:59:59 2024 GMT
    *  subjectAltName: host "www.trulia.com" matched cert's "*.trulia.com"
    *  issuer: C=US; O=Amazon; CN=Amazon RSA 2048 M01
    *  SSL certificate verify ok.
    } [5 bytes data]
    * using HTTP/2
    * h2 [:method: GET]
    * h2 [:authority: www.trulia.com]
    * h2 [:scheme: https]
    * h2 [:path: /home/2858-briarcliff-rd-atlanta-ga-30329-14543068]
    * h2 [cookie: _pxhd=DnyrPdmlSTpxmasBBW6hE1OpLiZuBr0S78J45xzLBeO3KxK5ICtTQDl9PRQt61WA5xA/43jPXvvDvTt0LM46aQ==:j78APZgKokn/j2mRDWwLnAjAil/b3CpeAbwjG2HgchdrLIEBEokhluec6J/kVzHVCkQ/3B287im5QvaRhsy4YmEyglWTC0uueYkp6Tl8aq8=; tabc=%7B%221274%22%3A%22a%22%2C%221337%22%3A%22b%22%2C%221341%22%3A%22b%22%2C%221353%22%3A%22b%22%2C%221365%22%3A%22b%22%2C%221377%22%3A%22b%22%2C%221386%22%3A%22b%22%2C%221395%22%3A%22b%22%2C%221406%22%3A%22a%22%2C%221409%22%3A%22b%22%2C%221425%22%3A%22a%22%2C%221437%22%3A%22a%22%2C%221439%22%3A%22b%22%2C%221440%22%3A%22b%22%2C%221444%22%3A%22a%22%2C%221452%22%3A%22a%22%2C%221461%22%3A%22a%22%2C%221464%22%3A%22a%22%2C%221468%22%3A%22control%22%2C%221469%22%3A%22a%22%7D; _csrfSecret=VO0vs5gE3r5yPshlILmbvuuG; tlftmusr=240125s7tgxfcr3s8ozn1bh3230am488]
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
    * Using Stream ID: 1 (easy handle 0x150810c00)
    } [5 bytes data]
    > GET /home/2858-briarcliff-rd-atlanta-ga-30329-14543068 HTTP/2
    > Host: www.trulia.com
    > Cookie: _pxhd=DnyrPdmlSTpxmasBBW6hE1OpLiZuBr0S78J45xzLBeO3KxK5ICtTQDl9PRQt61WA5xA/43jPXvvDvTt0LM46aQ==:j78APZgKokn/j2mRDWwLnAjAil/b3CpeAbwjG2HgchdrLIEBEokhluec6J/kVzHVCkQ/3B287im5QvaRhsy4YmEyglWTC0uueYkp6Tl8aq8=; tabc=%7B%221274%22%3A%22a%22%2C%221337%22%3A%22b%22%2C%221341%22%3A%22b%22%2C%221353%22%3A%22b%22%2C%221365%22%3A%22b%22%2C%221377%22%3A%22b%22%2C%221386%22%3A%22b%22%2C%221395%22%3A%22b%22%2C%221406%22%3A%22a%22%2C%221409%22%3A%22b%22%2C%221425%22%3A%22a%22%2C%221437%22%3A%22a%22%2C%221439%22%3A%22b%22%2C%221440%22%3A%22b%22%2C%221444%22%3A%22a%22%2C%221452%22%3A%22a%22%2C%221461%22%3A%22a%22%2C%221464%22%3A%22a%22%2C%221468%22%3A%22control%22%2C%221469%22%3A%22a%22%7D; _csrfSecret=VO0vs5gE3r5yPshlILmbvuuG; tlftmusr=240125s7tgxfcr3s8ozn1bh3230am488
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
    { [5 bytes data]
    * TLSv1.3 (IN), TLS handshake, Newsession Ticket (4):
    { [124 bytes data]
      0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0< HTTP/2 200 
    < content-type: text/html; charset=utf-8
    < date: Thu, 25 Jan 2024 12:23:21 GMT
    * Replaced cookie _pxhd="DnyrPdmlSTpxmasBBW6hE1OpLiZuBr0S78J45xzLBeO3KxK5ICtTQDl9PRQt61WA5xA/43jPXvvDvTt0LM46aQ==:j78APZgKokn/j2mRDWwLnAjAil/b3CpeAbwjG2HgchdrLIEBEokhluec6J/kVzHVCkQ/3B287im5QvaRhsy4YmEyglWTC0uueYkp6Tl8aq8=" for domain www.trulia.com, path /, expire 1737721401
    < set-cookie: _pxhd=DnyrPdmlSTpxmasBBW6hE1OpLiZuBr0S78J45xzLBeO3KxK5ICtTQDl9PRQt61WA5xA/43jPXvvDvTt0LM46aQ==:j78APZgKokn/j2mRDWwLnAjAil/b3CpeAbwjG2HgchdrLIEBEokhluec6J/kVzHVCkQ/3B287im5QvaRhsy4YmEyglWTC0uueYkp6Tl8aq8=; Expires=Fri, 24-Jan-25 12:23:21 GMT; Path=/
    < origin-trial: AmRXSF4LkPQ+d5bJH1+facuktYT0LjWujlO67VGWSWriQ5Oz9ePkAYVK47D5KBQQYHabwLyfE/7eN0wCPjf6KwgAAABYeyJvcmlnaW4iOiJodHRwczovL3d3dy50cnVsaWEuY29tOjQ0MyIsImZlYXR1cmUiOiJQcmlvcml0eUhpbnRzQVBJIiwiZXhwaXJ5IjoxNjQ3OTkzNTk5fQ==
    * Replaced cookie tlftmusr="240125s7tgxfcr3s8ozn1bh3230am488" for domain trulia.com, path /, expire 2147483647
    < set-cookie: tlftmusr=240125s7tgxfcr3s8ozn1bh3230am488; Path=/; Expires=Tue, 19 Jan 2038 03:14:07 GMT; Domain=.trulia.com
    * Replaced cookie tabc="%7B%221274%22%3A%22a%22%2C%221337%22%3A%22b%22%2C%221341%22%3A%22b%22%2C%221353%22%3A%22b%22%2C%221365%22%3A%22b%22%2C%221377%22%3A%22b%22%2C%221386%22%3A%22b%22%2C%221395%22%3A%22b%22%2C%221406%22%3A%22a%22%2C%221409%22%3A%22b%22%2C%221425%22%3A%22a%22%2C%221437%22%3A%22a%22%2C%221439%22%3A%22b%22%2C%221440%22%3A%22b%22%2C%221444%22%3A%22a%22%2C%221452%22%3A%22a%22%2C%221461%22%3A%22a%22%2C%221464%22%3A%22a%22%2C%221468%22%3A%22control%22%2C%221469%22%3A%22a%22%7D" for domain www.trulia.com, path /, expire 0
    < set-cookie: tabc=%7B%221274%22%3A%22a%22%2C%221337%22%3A%22b%22%2C%221341%22%3A%22b%22%2C%221353%22%3A%22b%22%2C%221365%22%3A%22b%22%2C%221377%22%3A%22b%22%2C%221386%22%3A%22b%22%2C%221395%22%3A%22b%22%2C%221406%22%3A%22a%22%2C%221409%22%3A%22b%22%2C%221425%22%3A%22a%22%2C%221437%22%3A%22a%22%2C%221439%22%3A%22b%22%2C%221440%22%3A%22b%22%2C%221444%22%3A%22a%22%2C%221452%22%3A%22a%22%2C%221461%22%3A%22a%22%2C%221464%22%3A%22a%22%2C%221468%22%3A%22control%22%2C%221469%22%3A%22a%22%7D; Path=/
    < x-csrf-token: AAhd+PQJcomXCIwPZ4b4K/LL/S3+k9PrV4X9Z08h
    < content-security-policy: frame-ancestors 'self' https://clipcentric-a.akamaihd.net https://clipcentric.com
    < cache-control: private, no-cache, no-store, max-age=0, must-revalidate
    < etag: "tg1f1z4b9h9dzt"
    < vary: Accept-Encoding
    < content-encoding: gzip
    < x-envoy-upstream-service-time: 271
    < server: istio-envoy
    < x-kong-upstream-latency: 274
    < x-kong-proxy-latency: 68
    < via: kong/2.5.1, 1.1 380ccc26a20ab9f0d2e398b093779842.cloudfront.net (CloudFront)
    < x-cache: Miss from cloudfront
    < x-amz-cf-pop: DFW57-P6
    < x-amz-cf-id: mrFgKFkuLsg1ruZssotlrVWINOgT4TSW6Axu_1pMkOsT3qV_e7YrdA==
    < 
    { [6828 bytes data]
    100 56368    0 56368    0     0   112k      0 --:--:-- --:--:-- --:--:--  112k
    * Connection #0 to host www.trulia.com left intact
    """

    uri = URI.parse("http://www.trulia.com/home/2858-briarcliff-rd-atlanta-ga-30329-14543068")

    assert %{headers: headers, uris: uris, status: status} =
             Curl.parse_metadata(stderr_output, uri)

    assert status == 200
    assert uris == [uri]

    assert headers == %{
             "cache-control" => ["private, no-cache, no-store, max-age=0, must-revalidate"],
             "content-encoding" => ["gzip"],
             "content-security-policy" => [
               "frame-ancestors 'self' https://clipcentric-a.akamaihd.net https://clipcentric.com"
             ],
             "content-type" => ["text/html; charset=utf-8"],
             "date" => ["Thu, 25 Jan 2024 12:23:21 GMT"],
             "etag" => ["\"tg1f1z4b9h9dzt\""],
             "origin-trial" => [
               "AmRXSF4LkPQ+d5bJH1+facuktYT0LjWujlO67VGWSWriQ5Oz9ePkAYVK47D5KBQQYHabwLyfE/7eN0wCPjf6KwgAAABYeyJvcmlnaW4iOiJodHRwczovL3d3dy50cnVsaWEuY29tOjQ0MyIsImZlYXR1cmUiOiJQcmlvcml0eUhpbnRzQVBJIiwiZXhwaXJ5IjoxNjQ3OTkzNTk5fQ=="
             ],
             "server" => ["istio-envoy"],
             "set-cookie" => [
               "_pxhd=DnyrPdmlSTpxmasBBW6hE1OpLiZuBr0S78J45xzLBeO3KxK5ICtTQDl9PRQt61WA5xA/43jPXvvDvTt0LM46aQ==:j78APZgKokn/j2mRDWwLnAjAil/b3CpeAbwjG2HgchdrLIEBEokhluec6J/kVzHVCkQ/3B287im5QvaRhsy4YmEyglWTC0uueYkp6Tl8aq8=; Expires=Fri, 24-Jan-25 12:23:21 GMT; Path=/",
               "tlftmusr=240125s7tgxfcr3s8ozn1bh3230am488; Path=/; Expires=Tue, 19 Jan 2038 03:14:07 GMT; Domain=.trulia.com",
               "tabc=%7B%221274%22%3A%22a%22%2C%221337%22%3A%22b%22%2C%221341%22%3A%22b%22%2C%221353%22%3A%22b%22%2C%221365%22%3A%22b%22%2C%221377%22%3A%22b%22%2C%221386%22%3A%22b%22%2C%221395%22%3A%22b%22%2C%221406%22%3A%22a%22%2C%221409%22%3A%22b%22%2C%221425%22%3A%22a%22%2C%221437%22%3A%22a%22%2C%221439%22%3A%22b%22%2C%221440%22%3A%22b%22%2C%221444%22%3A%22a%22%2C%221452%22%3A%22a%22%2C%221461%22%3A%22a%22%2C%221464%22%3A%22a%22%2C%221468%22%3A%22control%22%2C%221469%22%3A%22a%22%7D; Path=/"
             ],
             "vary" => ["Accept-Encoding"],
             "via" => [
               "kong/2.5.1, 1.1 380ccc26a20ab9f0d2e398b093779842.cloudfront.net (CloudFront)"
             ],
             "x-amz-cf-id" => ["mrFgKFkuLsg1ruZssotlrVWINOgT4TSW6Axu_1pMkOsT3qV_e7YrdA=="],
             "x-amz-cf-pop" => ["DFW57-P6"],
             "x-cache" => ["Miss from cloudfront"],
             "x-csrf-token" => ["AAhd+PQJcomXCIwPZ4b4K/LL/S3+k9PrV4X9Z08h"],
             "x-envoy-upstream-service-time" => ["271"],
             "x-kong-proxy-latency" => ["68"],
             "x-kong-upstream-latency" => ["274"]
           }
  end
end
