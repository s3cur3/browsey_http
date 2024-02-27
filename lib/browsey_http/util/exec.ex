defmodule BrowseyHttp.Util.Exec do
  @moduledoc false

  @spec exec(String.t(), non_neg_integer()) ::
          {:ok, [{:stdout | :stderr, [binary()]}]} | {:error, Keyword.t()}
  def exec(command, timeout) do
    :dockerexec.run(command, [:sync, :stdout, :stderr], timeout)
  end

  @spec running_as_root?() :: boolean()
  def running_as_root? do
    System.cmd("id", ["-u"], env: %{}) == {"0\n", 0}
  end
end
