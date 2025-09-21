defmodule BrowseyHttp.Util.Exec do
  @moduledoc false

  defmacrop dockerexec_loaded? do
    Code.ensure_loaded?(:dockerexec)
  end

  @spec exec(String.t(), timeout()) ::
          {:ok, [{:stdout | :stderr, [binary()]}]} | {:error, Keyword.t()}
  def exec(command, timeout) do
    opts = [:sync, :stdout, :stderr]

    full_command =
      if timeout == :infinity do
        command
      else
        # exec just straight up ignores the timeout argument they purport to support. :(
        "timeout #{ceil(timeout / 1_000)}s #{command}"
      end

    if dockerexec_loaded?() do
      :dockerexec.run(full_command, opts, timeout)
    else
      apply(:exec, :run, [full_command, opts, timeout])
    end
  end

  @spec running_as_root?() :: boolean()
  def running_as_root? do
    System.cmd("id", ["-u"], env: %{}) == {"0\n", 0}
  end
end
