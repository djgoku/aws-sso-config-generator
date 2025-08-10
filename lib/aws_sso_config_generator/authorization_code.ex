defmodule AwsSsoConfigGenerator.AuthorizationCode do
  require Logger

  def maybe_start_authorization_code(%{grant_type: :authorization_code} = config) do
    AwsSsoConfigGenerator.AuthorizationCode.Agent.start_link(nil)

    {:ok, server_pid} =
      Bandit.start_link(
        plug: {AwsSsoConfigGenerator.AuthorizationCode.Http, [parent_pid: self()]},
        port: 0,
        ip: :loopback
      )

    server_port =
      case get_server_port(server_pid) do
        {:ok, server_port} ->
          server_port

        _error ->
          System.halt(-1)
      end

    %{
      config
      | authorization_redirect_uri: "http://127.0.0.1:#{server_port}/oauth/callback",
        authorization_server_pid: server_pid
    }
  end

  def maybe_start_authorization_code(config), do: config

  def create_oidc_config(config) do
    [
      redirect_uri: config.authorization_redirect_uri,
      client_id: config.client_id,
      authorize_url: "https://oidc.#{config.sso_region}.amazonaws.com/authorize",
      code_verifier: true,
      authorization_params: [scopes: "sso:account:access"],
      token_url: "https://oidc.#{config.sso_region}.amazonaws.com/token",
      state: true,
      base_url: "https://oidc.#{config.sso_region}.amazonaws.com",
      auth_method: :client_secret_post
    ]
  end

  def authorize_url(oidc_config) do
    {:ok, %{url: authorize_url, session_params: session_params}} =
      Assent.Strategy.OAuth2.authorize_url(oidc_config)

    {authorize_url, session_params}
  end

  def get_server_port(server_pid) do
    case ThousandIsland.listener_info(server_pid) do
      {:ok, {_, server_port}} ->
        {:ok, server_port}

      error ->
        Logger.error(
          "#{__MODULE__}.get_server_port while getting listener_info errored with #{inspect(error)}"
        )

        error
    end
  end
end
