defmodule BrowseyHttp.Util.Enum do
  @moduledoc false

  # Mirrors Swift's compact_map(), but named to match Elixir's Enum module's compound actions.
  @spec map_compact(Enumerable.t(), (term -> nil | term())) :: Enumerable.t()
  def map_compact(enum, mapper) when is_function(mapper, 1) do
    # Roughly twice as fast as doing a map + filter:
    # https://github.com/s3cur3/elixir-bench#compact-map-ie-mapping-over-a-collection-then-removing-nil-values
    for val <- enum, mapped_val = mapper.(val), not is_nil(mapped_val) do
      mapped_val
    end
  end
end
