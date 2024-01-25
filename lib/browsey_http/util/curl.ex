defmodule BrowseyHttp.Util.Curl do
  @moduledoc false
  alias BrowseyHttp.Util

  @spec parse_metadata(String.t(), URI.t()) :: %{
          headers: BrowseyHttp.Response.headers(),
          uris: [URI.t()],
          status: integer() | nil
        }
  def parse_metadata(stderr_output, %URI{} = original_uri) do
    stderr_lines = String.split(stderr_output, ["\n", "\r\n"])

    responses =
      stderr_lines
      |> Enum.flat_map(fn line ->
        case String.split(line, "< HTTP/", parts: 2) do
          [progress, status] -> [progress, "< HTTP/" <> status]
          _ -> [line]
        end
      end)
      |> Enum.filter(&String.starts_with?(&1, ["< ", "> GET "]))
      |> Enum.chunk_by(&String.starts_with?(&1, "> GET "))
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        [["> GET " <> _ = get_header], response_lines] ->
          drop_switching_protocols([get_header | response_lines])

        [response_lines] ->
          drop_switching_protocols(response_lines)
      end)

    paths_naive =
      Enum.flat_map(responses, fn response_lines ->
        requested_paths =
          response_lines
          |> Enum.filter(&String.starts_with?(&1, "> GET"))
          |> Enum.map(fn line ->
            line
            |> String.trim_leading("> GET ")
            |> String.split(" ", parts: 2)
            |> List.first()
          end)

        headers =
          response_lines
          |> parse_headers()
          |> Map.new(fn {key, value} -> {String.downcase(key), value} end)

        if Map.has_key?(headers, "location") do
          requested_paths ++ Enum.map(Map.get(headers, "location"), &{:redirect, &1})
        else
          requested_paths
        end
      end)

    # Collapse /, https://example.com/, / down to just the / and redirect
    uris =
      paths_naive
      |> Enum.reduce([], fn
        path, [] when is_binary(path) ->
          [URI.merge(original_uri, URI.parse(path))]

        {:redirect, path}, [%URI{} = prev_uri | _] = acc ->
          [{:redirect, URI.merge(prev_uri, URI.parse(path))} | acc]

        path, [{:redirect, %URI{} = prev_uri} | tail] ->
          [URI.merge(prev_uri, URI.parse(path)) | tail]
      end)
      |> Enum.reduce([], fn
        {:redirect, _} = _untraveled_redirect, [] -> []
        %URI{} = uri, acc -> [uri | acc]
      end)

    last_response = List.last(responses)

    last_status =
      last_response
      |> Enum.filter(&String.starts_with?(&1, "< HTTP/"))
      |> List.last()
      |> String.split(" ", parts: 3)
      |> List.last()
      |> Util.Integer.from_string()
      |> case do
        {:ok, status} -> status
        _ -> nil
      end

    %{headers: parse_headers(last_response), uris: uris, status: last_status}
  end

  # Drop everything between "< HTTP/1.1 101 Switching Protocols" and "< HTTP/2 200"
  defp drop_switching_protocols(lines) do
    lines
    |> Enum.reduce([], fn
      "< HTTP/2 " <> _ = next, ["< HTTP/1.1 101 Switching Protocols" | _] = acc ->
        [next | acc]

      _, ["< HTTP/1.1 101 Switching Protocols" | _] = acc ->
        acc

      line, acc ->
        [line | acc]
    end)
    |> Enum.reverse()
  end

  defp parse_headers(stderr_response) do
    stderr_response
    |> Util.Enum.map_compact(fn line ->
      line
      |> String.trim_leading("< ")
      |> String.split(": ", parts: 2)
      |> then(fn
        [key, value] -> {key, value}
        _ -> nil
      end)
    end)
    |> BrowseyHttp.Response.proplist_to_headers()
  end
end
