defmodule AwsSsoConfigGenerator do
  require Logger
  alias AwsSsoConfigGenerator.Util

  defstruct access_token: nil,
            account_list: [],
            account_roles: [],
            args: [],
            client: nil,
            client_id: nil,
            client_secret: nil,
            client_name: "aws-sso-config-generator",
            device_code: nil,
            expires_in: nil,
            interval: nil,
            output_file: nil,
            register_client: nil,
            region: nil,
            sso_region: nil,
            start_url: nil,
            template: %{},
            template_file: nil,
            verification_uri_complete: nil

  def main(_) do
    # for escript use
    start("not", "used")
  end

  def start(_, _) do
    args = Util.parse_args(Burrito.Util.Args.argv())

    if Keyword.get(args, :help) do
      IO.puts(Util.get_help())
      System.halt(0)
    end

    config =
      %AwsSsoConfigGenerator{args: args}
      |> Util.map_args()
      |> Util.get_region()
      |> Util.get_start_url()
      |> Util.sso_oidc_register_client()
      |> Util.sso_oidc_start_device_authorization()

    output = """
    aws-sso-config-generator #{Application.spec(:aws_sso_config_generator, :vsn)}

    Tool to generate an AWS config file (~/.aws/config) after authenticating and authorizing AWS SSO IAM Identity Center.

    Source code: https://github.com/djgoku/aws-sso-config-generator

    Verification URI (copy and paste into browser if it doesn't open.)

      #{config.verification_uri_complete}
    """

    IO.puts(output)

    Util.browser_open(config.verification_uri_complete)

    maybe_access_token = Util.request_until(config, config.expires_in)

    if is_nil(maybe_access_token) do
      Logger.error("Unable to create token")
      exit(:error_unabled_to_create_token)
    end

    config_data =
      %{config | access_token: maybe_access_token}
      |> Util.sso_list_accounts(nil)
      |> Util.sso_list_account_roles()
      |> Util.duplicate_keys_with_new_keys()
      |> Util.maybe_load_template()
      |> Util.maybe_save_debug_data()
      |> Util.maybe_rename_accounts_and_roles()
      |> Util.generate_config()
      |> Enum.join("\n")

    File.write(config.output_file, config_data)
    IO.puts("wrote generated to #{config.output_file}")

    System.halt(0)
  end
end
