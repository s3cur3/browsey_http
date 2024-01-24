defmodule BrowseyHttp.Util.Integer do
  @moduledoc false

  @spec from_string(String.t()) :: {:ok, integer()} | :error
  def from_string(string) when is_binary(string) do
    string
    |> String.trim()
    |> Integer.parse()
    |> case do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end
end
