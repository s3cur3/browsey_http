defmodule BrowseyHttp.Curl do
  @moduledoc false
  alias BrowseyHttp.Util

  @spec parse_metadata(String.t()) :: %{
          headers: BrowseyHttp.Response.headers(),
          paths: [String.t()],
          status: integer() | nil
        }
  def parse_metadata(stderr_output) do
    stderr_lines = String.split(stderr_output, ["\n", "\r\n"])

    paths =
      stderr_lines
      |> Enum.filter(&String.starts_with?(&1, "> GET"))
      |> Enum.map(fn line ->
        line
        |> String.trim_leading("> GET ")
        |> String.split(" ", parts: 2)
        |> List.first()
      end)

    responses =
      stderr_lines
      |> Enum.flat_map(fn line ->
        case String.split(line, "< HTTP/", parts: 2) do
          [progress, status] -> [progress, "< HTTP/" <> status]
          _ -> [line]
        end
      end)
      |> Enum.filter(&String.starts_with?(&1, "<"))
      |> Enum.chunk_by(&String.starts_with?(&1, "< HTTP/"))
      |> Enum.chunk_every(2)
      |> Enum.map(fn [["< HTTP/" <> _ = http_header], response_lines] ->
        [http_header | response_lines]
      end)

    last_response = List.last(responses)

    last_status =
      last_response
      |> List.first()
      |> String.split(" ", parts: 3)
      |> List.last()
      |> Util.Integer.from_string()
      |> case do
        {:ok, status} -> status
        _ -> nil
      end

    %{headers: parse_headers(last_response), paths: paths, status: last_status}
  end

  defp parse_headers(["< HTTP" <> _ | stderr_response]) do
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
