defmodule AwsSsoConfigGenerator do
  require Logger
  alias AwsSsoConfigGenerator.Util

  @dialyzer {:nowarn_function, start: 2, main: 1}

  defstruct access_token: nil,
            account_list: [],
            account_roles: [],
            args: [],
            authorization_code: nil,
            authorization_code_verifier: nil,
            authorization_redirect_uri: nil,
            authorization_server_pid: nil,
            client: nil,
            client_id: nil,
            client_secret: nil,
            client_name: "aws-sso-config-generator",
            device_code: nil,
            expires_in: nil,
            grant_type: :authorization_code,
            iam_identity_center: [],
            interval: nil,
            legacy_iam_identity_center: [],
            output_file: nil,
            register_client: nil,
            region: nil,
            sso_region: nil,
            sso_session_name: "my-sso",
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
      |> Util.get_sso_session_name()
      |> AwsSsoConfigGenerator.AuthorizationCode.maybe_start_authorization_code()
      |> Util.sso_oidc_register_client()
      |> Util.sso_oidc_start_authorization()

    output = Util.console_output(config.verification_uri_complete)
    IO.puts(output)

    Util.browser_open(config.verification_uri_complete)

    maybe_access_token =
      if config.grant_type == :device_code do
        Util.request_until(config, config.expires_in)
      else
        # :authorization_code we need to way for a message from
        # AwsSsoConfigGenerator.AuthorizationCode.Http that the
        # callback was called
        receive do
          :shutdown ->
            Logger.debug("Shutdown message received. Stopping server")
        end

        Process.exit(config.authorization_server_pid, :normal)

        code = AwsSsoConfigGenerator.AuthorizationCode.Agent.get()
        config = %{config | authorization_code: code}
        Util.request_until(config, 30)
      end

    if is_nil(maybe_access_token) do
      Logger.error("Unable to create token")
      exit(:error_unabled_to_create_token)
    end

    config =
      %{config | access_token: maybe_access_token}
      |> Util.sso_list_accounts(nil)
      |> Util.sso_list_account_roles()
      |> Util.duplicate_keys_with_new_keys()
      |> Util.maybe_load_template()
      |> Util.maybe_save_debug_data()
      |> Util.maybe_rename_accounts_and_roles()
      |> Util.generate_config()

    File.write(config.output_file, config.iam_identity_center |> Enum.join("\n"))
    IO.puts("wrote generated to #{config.output_file}")

    legacy_output_file = "#{config.output_file}-legacy"
    File.write(legacy_output_file, config.legacy_iam_identity_center |> Enum.join("\n"))
    IO.puts("wrote generated to #{legacy_output_file}")

    System.halt(0)
  end
end
