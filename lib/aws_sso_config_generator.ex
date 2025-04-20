defmodule AwsSsoConfigGenerator do
  require Logger
  alias AwsSsoConfigGenerator.Util

  defstruct access_token: nil,
            account_list: [],
            account_roles: [],
            client: nil,
            client_id: nil,
            client_secret: nil,
            client_name: "aws-sso-config-generator",
            device_code: nil,
            expires_in: nil,
            interval: nil,
            register_client: nil,
            region: nil,
            start_url: nil,
            verification_uri_complete: nil

  def start(_, _) do
    args = Util.parse_args(Burrito.Util.Args.argv())

    if Keyword.get(args, :help) do
      IO.puts(Util.get_help())
      System.halt(0)
    end

    aws_region = Util.get_region(args)
    start_url = Util.get_start_url(args)

    config =
      %AwsSsoConfigGenerator{
        region: aws_region,
        start_url: start_url,
        client: %AWS.Client{region: aws_region}
      }
      |> Util.sso_oidc_register_client()
      |> Util.sso_oidc_start_device_authorization()

    Util.browser_open(config.verification_uri_complete)

    IO.puts(
      "\nVerification URI (copy and paste into browser if it doesn't open.)\n\n  #{config.verification_uri_complete}\n\n"
    )

    maybe_access_token = Util.request_until(config, config.expires_in)

    if is_nil(maybe_access_token) do
      Logger.error("Unable to create token")
      exit(:error_unabled_to_create_token)
    end

    config_data =
      %{config | access_token: maybe_access_token}
      |> Util.sso_list_accounts(nil)
      |> Util.sso_list_account_roles()
      |> Util.config_sort_account_roles()
      |> Util.generate_config()
      |> Enum.join("\n")

    file_path = Path.join(System.user_home!(), ".aws/config.generated")
    File.write(file_path, config_data)
    IO.puts("wrote generated to #{file_path}")

    System.halt(0)
  end
end
