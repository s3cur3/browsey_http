defmodule BrowseyHttp.Util.Exec do
  @moduledoc false

  defmacrop dockerexec_loaded? do
    Code.ensure_loaded?(:dockerexec)
  end

  @spec exec(String.t(), timeout()) ::
          {:ok, [{:stdout | :stderr, [binary()]}]} | {:error, Keyword.t()}
  def exec(command, timeout) do
    opts = [:sync, :stdout, :stderr]

    if dockerexec_loaded?() do
      :dockerexec.run(command, opts, timeout)
    else
      apply(:exec, :run, [add_shell_timeout(command, timeout), opts, timeout])
    end
  end

  @spec running_as_root?() :: boolean()
  def running_as_root? do
    System.cmd("id", ["-u"], env: %{}) == {"0\n", 0}
  end

  @spec add_shell_timeout(String.t(), timeout()) :: String.t()
  defp add_shell_timeout(command, :infinity), do: command

  defp add_shell_timeout(command, timeout) do
    case timeout_command() do
      nil -> command
      timeout_binary -> "#{timeout_binary} #{ceil(timeout / 1_000)}s #{command}"
    end
  end

  @spec timeout_command() :: String.t() | nil
  defp timeout_command do
    cond do
      timeout = System.find_executable("timeout") -> timeout
      timeout = System.find_executable("gtimeout") -> timeout
      true -> nil
    end
  end
end
