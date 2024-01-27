defmodule BrowseyHttp.ConnectionException do
  @moduledoc false
  defexception [:message, :uri, :error_code]

  @type t() :: %__MODULE__{
          message: String.t(),
          uri: URI.t(),
          error_code: non_neg_integer()
        }

  @spec could_not_connect(URI.t()) :: t()
  def could_not_connect(%URI{} = uri) do
    %__MODULE__{
      message: "Could not connect to host",
      uri: uri,
      error_code: 7
    }
  end

  @spec invalid_url(URI.t()) :: t()
  def invalid_url(%URI{} = uri) do
    %__MODULE__{
      message: "Invalid URL",
      uri: uri,
      error_code: 3
    }
  end

  @spec could_not_resolve_host(URI.t()) :: t()
  def could_not_resolve_host(%URI{} = uri) do
    %__MODULE__{
      message: "Could not resolve host",
      uri: uri,
      error_code: 6
    }
  end

  @spec failed_to_receive(URI.t()) :: t()
  def failed_to_receive(%URI{} = uri) do
    %__MODULE__{
      message: "Failure while receiving data",
      uri: uri,
      error_code: 56
    }
  end

  @spec unknown_error(URI.t(), non_neg_integer) :: t()
  def unknown_error(%URI{} = uri, error_code) do
    %__MODULE__{
      message: "Failed to retrieve URL",
      uri: uri,
      error_code: error_code
    }
  end
end
