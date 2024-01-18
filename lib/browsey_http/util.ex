defmodule BrowseyHttp.Util do
  @moduledoc """
  A set of utility functions for use all over the project.
  """

  def then_if(val, true, fun), do: fun.(val)
  def then_if(val, false, _fun), do: val
  def then_if(val, nil, _fun), do: val
end
