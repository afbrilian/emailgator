defmodule Emailgator.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Emailgator.Repo,
      {Phoenix.PubSub, name: Emailgator.PubSub},
      EmailgatorWeb.Endpoint,
      {Oban, Application.get_env(:emailgator_api, Oban)}
    ]

    opts = [strategy: :one_for_one, name: Emailgator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    EmailgatorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
