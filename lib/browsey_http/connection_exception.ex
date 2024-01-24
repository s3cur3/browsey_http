defmodule BrowseyHttp.ConnectionException do
  @moduledoc false
  defexception [:message, :uri, :error_code]

  def could_not_connect(%URI{} = uri) do
    error_code = 7

    %__MODULE__{
      message: "Could not connect to host. Error #{inspect(error_code)}",
      uri: uri,
      error_code: error_code
    }
  end

  def could_not_resolve_host(%URI{} = uri) do
    error_code = 6

    %__MODULE__{
      message: "Could not resolve host. Error #{inspect(error_code)}",
      uri: uri,
      error_code: error_code
    }
  end

  def unknown_error(%URI{} = uri, error_code) do
    %__MODULE__{
      message: "Failed to retrieve URL. Error #{inspect(error_code)}",
      uri: uri,
      error_code: error_code
    }
  end
end
