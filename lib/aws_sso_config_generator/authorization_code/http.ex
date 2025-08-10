defmodule AwsSsoConfigGenerator.AuthorizationCode.Http do
  import Plug.Conn
  require Logger

  def init(options) do
    Keyword.fetch!(options, :parent_pid)
  end

  def call(conn, server_pid) do
    Logger.debug("#{__MODULE__}.call conn #{inspect(conn)} --- params #{inspect(server_pid)}")

    query_string = Map.get(conn, :query_string)

    code =
      query_string
      |> URI.query_decoder()
      |> Keyword.new(fn {k, v} -> {String.to_atom(k), v} end)
      |> Keyword.get(:code)

    Logger.debug("#{__MODULE__}.call query_string #{inspect(query_string)}")

    code =
      if not is_nil(code) do
        AwsSsoConfigGenerator.AuthorizationCode.Agent.set(code)
        code
      else
        AwsSsoConfigGenerator.AuthorizationCode.Agent.get()
      end

    Logger.debug("#{__MODULE__}.call code #{code}")

    send(server_pid, :shutdown)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, AwsSsoConfigGenerator.AuthorizationCode.Html.html())
  end
end
