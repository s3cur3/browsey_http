defmodule BrowseyHttp.Util.Exec do
  @moduledoc false

  defmacrop dockerexec_loaded? do
    Code.ensure_loaded?(:dockerexec)
  end

  @spec exec(String.t(), non_neg_integer()) ::
          {:ok, [{:stdout | :stderr, [binary()]}]} | {:error, Keyword.t()}
  def exec(command, timeout) do
    opts = [:sync, :stdout, :stderr]

    if dockerexec_loaded?() do
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
