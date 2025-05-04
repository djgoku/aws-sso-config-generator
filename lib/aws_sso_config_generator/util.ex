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
        strict: [
          region: :string,
          sso_region: :string,
          start_url: :string,
          help: :boolean,
          template: :string,
          out: :string,
          debug: :boolean
        ],
        aliases: [r: :region, u: :start_url, h: :help, t: :template, o: :out]
      )

    parsed
  end

  def map_args(config) do
    template_file =
      Path.expand(
        Keyword.get(
          config.args,
          :template,
          Path.join(System.user_home!(), ".aws/config.template.json")
        )
      )

    output_file =
      Path.expand(
        Keyword.get(config.args, :out, Path.join(System.user_home!(), ".aws/config.generated"))
      )

    %{config | template_file: template_file, output_file: output_file}
  end

  def get_help() do
    """
    aws-sso-config-generator #{Application.spec(:aws_sso_config_generator, :vsn)}

    Tool to generate an AWS config file (~/.aws/config) (our file is saved to ~/.aws/config.generated) after authenticating and authorizing AWS SSO IAM Identity Center.

    Source code: https://github.com/djgoku/aws-sso-config-generator

    Usage: aws-sso-config-generator [options]

    Examples:

        aws-sso-config-generator -r us-west-2 --sso-region us-east-1 -u https://<example>.awsapps.com/start/#/
        aws-sso-config-generator (Prompts for region and start url)

    Options:

    --sso-region     - Region where AWS access portal is hosted.
    --region|-r      - Region where AWS resources are hosted.
    --start-url|-u   - The URL for the AWS access portal
    --help|-h        - Help menu
    --template|-t    - JSON template file to re-map accounts and roles defaults to ~/.aws/config.template.json
    --out|-o         - Output file which defaults to ~/.aws/config.generated
    """
  end

  def get_start_url(config) do
    start_url =
      Keyword.get(
        config.args,
        :start_url
      ) ||
        Prompt.text("Enter sso start url (e.g.: https://<an-example.com>.awsapps.com/start/#/)")

    Map.put(config, :start_url, start_url)
  end

  def get_region(config) do
    region =
      Keyword.get(config.args, :region) ||
        Prompt.text("Enter aws region where AWS resources are hosted (e.g.: us-west-2)")

    sso_region =
      Keyword.get(config.args, :sso_region) ||
        Prompt.text("Enter aws region where AWS access portal is hosted (e.g.: us-west-2)")

    config
    |> Map.put(:region, region)
    |> Map.put(:client, %AWS.Client{region: sso_region})
    |> Map.put(:sso_region, sso_region)
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
        aws_request_options()
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
        aws_request_options()
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
      aws_request_options()
    )
  end

  def sso_list_accounts(config, current_token) do
    case AWS.SSO.list_accounts(
           config.client,
           nil,
           current_token,
           config.access_token,
           aws_request_options()
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
      AWS.SSO.list_account_roles(
        config.client,
        account_id,
        nil,
        nil,
        config.access_token,
        aws_request_options()
      )

    role_list
  end

  def maybe_save_debug_data(config) do
    if Keyword.get(config.args, :debug) do
      debug_file = Path.expand(Path.join(System.user_home!(), ".aws/config.debug.exs"))
      Logger.debug("Debug mode enabled saving config to #{debug_file}")

      config =
        Map.take(config, [
          :account_list,
          :account_roles,
          :region,
          :start_url,
          :output_file,
          :template,
          :template_file
        ])

      File.write!(debug_file, inspect(config), limit: :infinity, printable_limit: :infinity)
    end

    config
  end

  def maybe_load_template(config) do
    if File.exists?(config.template_file) do
      Logger.info("Loaded template #{config.template_file}")
      json = File.read!(config.template_file) |> JSON.decode!()

      json =
        ["accounts", "roles"]
        |> Enum.reduce(json, fn key, json -> add_missing_template_key(json, key) end)

      Map.put(config, :template, json)
    else
      config
    end
  end

  def add_missing_template_key(json, key) do
    if is_map_key(json, key) do
      json
    else
      Map.put(json, key, %{})
    end
  end

  def duplicate_keys_with_new_keys(config) do
    account_roles =
      config.account_roles
      |> Enum.map(fn map ->
        account_id = Map.get(map, "accountId")
        role_name = Map.get(map, "roleName")

        map
        |> Map.put("accountIdNew", account_id)
        |> Map.put("roleNameNew", role_name)
      end)

    %{config | account_roles: account_roles}
  end

  def maybe_rename_accounts_and_roles(config) when map_size(config.template) == 0, do: config

  def maybe_rename_accounts_and_roles(config) do
    account_roles =
      config.account_roles
      |> Enum.map(fn account_role ->
        account_role
        |> maybe_update_account_or_role("accountId", config.template, "accounts")
        |> maybe_update_account_or_role("roleName", config.template, "roles")
      end)

    %{config | account_roles: account_roles}
  end

  def maybe_update_account_or_role(account_role, account_role_key, template, template_key) do
    account_role_key_value = Map.get(account_role, account_role_key)

    template_map = Map.get(template, template_key)

    case Map.get(template_map, account_role_key_value) do
      nil ->
        account_role

      new_value ->
        Map.put(account_role, "#{account_role_key}New", new_value)
    end
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

  def config_template(config, %{
        "accountId" => account_id,
        "accountIdNew" => account_id_new,
        "roleName" => role_name,
        "roleNameNew" => role_name_new
      }) do
    profile =
      if String.length(role_name_new) == 0 do
        account_id_new
      else
        "#{account_id_new}-#{role_name_new}"
      end

    """
    # AWS_CONFIG_FILE=~/.aws/config.generated AWS_PROFILE=#{profile} aws sts get-caller-identity
    [profile #{profile}]
    sso_start_url = #{config.start_url}
    sso_region = #{config.sso_region}
    sso_account_id = #{account_id}
    sso_role_name = #{role_name}
    region = #{config.region}
    output = json
    """
  end

  def generate_config(config) do
    profiles =
      config.account_roles
      |> Enum.map(fn account_role ->
        config_template(config, account_role)
      end)
      |> Enum.sort()

    [config_template_header()] ++ profiles
  end

  def aws_request_options() do
    [sign_request?: false, enable_retries?: true]
  end
end
