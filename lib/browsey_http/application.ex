defmodule BrowseyHttp.Application do
  @moduledoc false

  use Application

  alias BrowseyHttp.Util.Exec

  @impl Application
  def start(_type, _args) do
    docker_allow_root_args =
      if Exec.running_as_root?() do
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
