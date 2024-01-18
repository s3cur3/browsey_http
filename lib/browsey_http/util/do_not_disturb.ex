defmodule BrowseyHttp.Util.DoNotDisturb do
  @moduledoc false
  @doc """
  Executes a function and redirects all messages it sends to the calling process to /dev/null.

  Note that if you raise an exception, it won't bubble up to the calling process.
  """
  @spec run_silent((-> any()), timeout()) :: {:ok, any()} | {:error, :timeout}
  def run_silent(fun, :infinity) when is_function(fun, 0) do
    pid = run(fun)

    receive do
      {:dnd_result, ^pid, result} -> {:ok, result}
    end
  end

  def run_silent(fun, timeout) when is_function(fun, 0) and is_integer(timeout) do
    pid = run(fun)

    receive do
      {:dnd_result, ^pid, result} -> {:ok, result}
    after
      timeout ->
        Process.exit(pid, :kill)

        receive do
          {:dnd_result, ^pid, result} -> {:ok, result}
        after
          10 -> {:error, :timeout}
        end
    end
  end

  defp run(fun) do
    receiver = self()

    spawn(fn ->
      send(receiver, {:dnd_result, self(), fun.()})
    end)
  end
end
