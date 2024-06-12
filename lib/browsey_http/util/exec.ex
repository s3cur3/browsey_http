defmodule BrowseyHttp.Util.Exec do
  @moduledoc false

  @spec exec(String.t(), non_neg_integer()) ::
          {:ok, [{:stdout | :stderr, [binary()]}]} | {:error, Keyword.t()}
  def exec(command, timeout) do
    opts = [:sync, :stdout, :stderr]

    if Code.ensure_loaded?(:dockerexec) do
      :dockerexec.run(command, opts, timeout)
    else
      apply(:exec, :run, [command, opts, timeout])
    end
  end

  @spec running_as_root?() :: boolean()
  def running_as_root? do
    System.cmd("id", ["-u"], env: %{}) == {"0\n", 0}
  end
end
