defmodule BrowseyHttp.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    if is_nil(System.get_env("SHELL")) do
      System.put_env("SHELL", "/bin/sh")
    end

    Supervisor.start_link([], strategy: :one_for_one)
  end
end
