defmodule BrowseyHttp.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    if is_nil(System.get_env("SHELL")) do
      System.put_env("SHELL", "/bin/sh")
    end

    docker_allow_root_args =
      if BrowseyHttp.Util.Exec.running_as_root?() do
        [:root, user: "root", limit_users: ["root"]]
      else
        []
      end

    children = [
      %{
        id: :exec,
        start: {:exec, :start_link, [docker_allow_root_args]},
        restart: :permanent
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
