defmodule BrowseyHttp.TooManyRedirectsException do
  @moduledoc """
  The error returned when we exceed the maximum number of redirects while loading a resource.
  """
  defexception [:message, :uri, :max_redirects]

  def new(%URI{} = uri, max_redirects) do
    %__MODULE__{
      message: "Exceeded #{max_redirects} redirects",
      uri: uri,
      max_redirects: max_redirects
    }
  end
end
