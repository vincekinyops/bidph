defmodule Bidph.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BidphWeb.Telemetry,
      Bidph.Repo,
      {DNSCluster, query: Application.get_env(:bidph, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Bidph.PubSub},
      # Start a worker by calling: Bidph.Worker.start_link(arg)
      # {Bidph.Worker, arg},
      # Start to serve requests, typically the last entry
      BidphWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Bidph.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BidphWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
