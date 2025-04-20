defmodule AwsSsoConfigGenerator.Util do
  require Logger

  @doc """
  Opens the given `url` in the browser.

  Taken from https://github.com/livebook-dev/livebook/blob/75e47aa59318bbc7b2cf0f423e785e4c55d55f62/lib/livebook/utils.ex#L336-L365
  """
  def browser_open(url) do
    win_cmd_args = ["/c", "start", String.replace(url, "&", "^&")]

    cmd_args =
      case :os.type() do
        {:win32, _} ->
          {"cmd", win_cmd_args}

        {:unix, :darwin} ->
          {"open", [url]}

        {:unix, _} ->
          cond do
            System.find_executable("xdg-open") -> {"xdg-open", [url]}
            # When inside WSL
            System.find_executable("cmd.exe") -> {"cmd.exe", win_cmd_args}
            true -> nil
          end
      end

    case cmd_args do
      {cmd, args} -> System.cmd(cmd, args)
      nil -> Logger.warning("could not open the browser, no open command found in the system")
    end

    :ok
  end

  def parse_args(args) do
    {parsed, _, _} =
      OptionParser.parse(args,
        strict: [region: :string, start_url: :string, help: :boolean],
        aliases: [r: :region, u: :start_url, h: :help]
      )

    parsed
  end

  def get_help() do
    """
    aws-sso-config-generator #{Application.spec(:aws_sso_config_generator, :vsn)}

    Tool to generate an AWS config file (~/.aws/config) (our file is saved to ~/.aws/config.generated) after authenticating and authorizing AWS SSO IAM Identity Center.

    Source code: https://github.com/djgoku/aws-sso-config-generator

    Usage: aws-sso-config-generator [options]

    Examples:

        aws-sso-config-generator -r us-west-2 -u https://<example>.awsapps.com/start/#/
        aws-sso-config-generator (Prompts for region and start url)

    Options:

    --region|-r      - Region where AWS access portal is hosted.
    --start-url|-u   - The URL for the AWS access portal
    --help|-h        - Help menu
    """
  end

  def get_start_url(args) do
    Keyword.get(
      args,
      :start_url
    ) ||
      Prompt.text("Enter sso start url (e.g.: https://<an-example.com>.awsapps.com/start/#/)")
  end

  def get_region(args) do
    Keyword.get(args, :region) || Prompt.text("Enter aws region (e.g.: us-west-2)")
  end

  def request_until(config, expires_in) do
    case sso_oidc_create_token(config) do
      {:ok, %{"accessToken" => access_token}, _} ->
        access_token

      {:error, {:unexpected_response, %{body: body}}} ->
        case JSON.decode!(body) do
          %{"error" => "authorization_pending"} ->
            Process.sleep(config.interval * 1000)

            if expires_in > 0 do
              request_until(config, expires_in - 1)
            else
              exit(:request_exceeded_expiration)
            end

          error ->
            Logger.error("#{__MODULE__}.request_until errored with #{error}")
            exit(:request_errored)
        end
    end
  end

  def sso_oidc_register_client(config) do
    {:ok, %{"clientId" => client_id, "clientSecret" => client_secret} = register_client, _} =
      AWS.SSOOIDC.register_client(
        config.client,
        %{"clientName" => config.client_name, "clientType" => "public"},
        sign_request?: false
      )

    %{
      config
      | client_id: client_id,
        client_secret: client_secret,
        register_client: register_client
    }
  end

  def sso_oidc_start_device_authorization(config) do
    {:ok,
     %{
       "deviceCode" => device_code,
       "expiresIn" => expires_in,
       "interval" => interval,
       "verificationUriComplete" => verification_uri_complete
     },
     _other} =
      AWS.SSOOIDC.start_device_authorization(
        config.client,
        %{
          "clientId" => config.client_id,
          "clientSecret" => config.client_secret,
          "startUrl" => config.start_url
        },
        sign_request?: false
      )

    %{
      config
      | device_code: device_code,
        expires_in: expires_in,
        interval: interval,
        verification_uri_complete: verification_uri_complete
    }
  end

  def sso_oidc_create_token(config) do
    request = %{
      "clientId" => config.client_id,
      "clientSecret" => config.client_secret,
      "grantType" => "urn:ietf:params:oauth:grant-type:device_code",
      "deviceCode" => config.device_code
    }

    AWS.SSOOIDC.create_token(
      config.client,
      request,
      sign_request?: false
    )
  end

  def sso_list_accounts(config, current_token) do
    case AWS.SSO.list_accounts(config.client, nil, current_token, config.access_token,
           sign_request?: false
         ) do
      {:ok, %{"accountList" => account_list, "nextToken" => next_token}, _} ->
        if is_nil(next_token) do
          %{config | account_list: config.account_list ++ account_list}
        else
          sso_list_accounts(config, next_token)
        end
    end
  end

  def sso_list_account_roles(config) do
    account_roles =
      Enum.reduce(config.account_list, [], fn account, acc ->
        acc ++ sso_list_account_roles(config, Map.get(account, "accountId"))
      end)

    %{config | account_roles: account_roles}
  end

  def sso_list_account_roles(config, account_id) do
    {:ok, %{"roleList" => role_list}, _} =
      AWS.SSO.list_account_roles(config.client, account_id, nil, nil, config.access_token,
        sign_request?: false
      )

    role_list
  end

  def config_sort_account_roles(config) do
    account_roles =
      config.account_roles
      |> Enum.sort_by(&Map.get(&1, "accountId"))

    %{config | account_roles: account_roles}
  end

  def config_template_header() do
    """
    # config generated via https://github.com/djgoku/aws-sso-config-generator
    #
    # This requires AWS CLI v2
    #
    # 1. log into aws sso via `aws sso login --profile use-any-profile-name`
    # 2. validate `AWS_PROFILE=use-any-profile-name aws sts get-caller-identity`
    """
  end

  def config_template(config, %{"accountId" => account_id, "roleName" => role_name}) do
    """
    # AWS_PROFILE=#{account_id}-#{role_name} aws sts get-caller-identity
    [profile #{account_id}-#{role_name}]
    sso_start_url = #{config.start_url}
    sso_region = #{config.region}
    sso_account_id = #{account_id}
    sso_role_name = #{role_name}
    region = us-west-2
    output = json
    """
  end

  def generate_config(config) do
    [config_template_header()] ++
      Enum.map(config.account_roles, fn account_role ->
        config_template(config, account_role)
      end)
  end
end
