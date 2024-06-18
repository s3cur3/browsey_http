defmodule BrowseyHttp.Util.Exec do
  @moduledoc false

  @type result :: %{stdout: binary(), stderr: binary(), exit_status: integer()}

  @spec exec(String.t(), [String.t()], timeout()) :: {:ok, result()} | {:error, result()}
  def exec(command, args, timeout) do
    timeout_opts = if timeout == :infinity, do: [], else: [timeout: timeout]

    IO.inspect(command, label: "command")

    fn ->
      Rambo.run(command, args, [{:log, false} | timeout_opts])
    end
    |> Task.async()
    |> Task.await()
    |> case do
      {:ok, %Rambo{out: stdout, err: stderr, status: 0}} ->
        {:ok, %{stdout: stdout, stderr: stderr, exit_status: 0}}

      {:error, %Rambo{out: stdout, err: stderr, status: status}} ->
        {:error, %{stdout: stdout, stderr: stderr, exit_status: status}}

      {:error, msg} when is_binary(msg) ->
        {:error, %{stdout: "", stderr: msg, exit_status: -8_675_309}}
    end
  end

  @spec running_as_root?() :: boolean()
  def running_as_root? do
    System.cmd("id", ["-u"], env: %{}) == {"0\n", 0}
  end
end
