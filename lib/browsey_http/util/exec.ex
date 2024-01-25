defmodule BrowseyHttp.Util.Exec do
  @moduledoc false

  @spec exec(String.t(), non_neg_integer()) ::
          {:ok, [{:stdout | :stderr, [binary()]}]} | {:error, Keyword.t()}
  def exec(command, timeout) do
    if Code.ensure_loaded?(:exec) do
      :exec.run(command, [:sync, :stdout, :stderr], timeout)
    else
      raise """
      BrowseyHttp requires the `:exec` library to be loaded. Please add `:exec` to your
      `mix.exs` file's `extra_applications` list.
      """
    end
  end
end
