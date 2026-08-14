defmodule AwsSsoConfigGenerator.SsoPaginationTest do
  use ExUnit.Case

  defmodule FakeSsoPlug do
    import Plug.Conn

    def init(opts), do: opts

    def call(%Plug.Conn{path_info: ["assignment", "roles"]} = conn, _opts) do
      conn = fetch_query_params(conn)

      body =
        case conn.query_params["next_token"] do
          nil ->
            %{
              "roleList" => [%{"accountId" => "111111", "roleName" => "Admin"}],
              "nextToken" => "page-2"
            }

          "page-2" ->
            # last page: AWS omits nextToken
            %{"roleList" => [%{"accountId" => "111111", "roleName" => "ReadOnly"}]}
        end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, JSON.encode!(body))
    end
  end

  test "sso_list_account_roles follows nextToken across all pages" do
    server = start_supervised!({Bandit, plug: FakeSsoPlug, port: 0, ip: :loopback})
    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)

    client =
      AWS.Client.create("test-access-key", "test-secret-key", "us-east-1")
      |> AWS.Client.put_endpoint("localhost")
      |> Map.merge(%{proto: "http", port: port})

    config = %AwsSsoConfigGenerator{client: client, access_token: "test-token"}

    role_list = AwsSsoConfigGenerator.Util.sso_list_account_roles(config, "111111")

    assert role_list == [
             %{"accountId" => "111111", "roleName" => "Admin"},
             %{"accountId" => "111111", "roleName" => "ReadOnly"}
           ]
  end
end
