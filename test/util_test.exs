defmodule AwsSsoConfigGenerator.UtilTest do
  use ExUnit.Case
  doctest AwsSsoConfigGenerator

  describe "maybe_rename_accounts_and_roles/1" do
    test "all_accounts_and_roles_updated" do
      template =
        JSON.decode!(
          "{\"accounts\":{\"111111\":\"dev\",\"222222\":\"uat\",\"333333\":\"prod\"},\"roles\":{\"Admin\":\"\",\"ReadOnly\":\"read\"}}"
        )

      config = %AwsSsoConfigGenerator{
        account_roles: [
          %{"accountId" => "333333", "roleName" => "ReadOnly"},
          %{"accountId" => "333333", "roleName" => "Admin"},
          %{"accountId" => "111111", "roleName" => "ReadOnly"},
          %{"accountId" => "111111", "roleName" => "Admin"},
          %{"accountId" => "222222", "roleName" => "ReadOnly"},
          %{"accountId" => "222222", "roleName" => "Admin"}
        ],
        region: "us-east-1",
        sso_region: "us-west-2",
        start_url: "https://example.com/start/#/",
        template: %{},
        template_file: Path.join(File.cwd!(), "test/template.json")
      }

      config =
        config
        |> AwsSsoConfigGenerator.Util.duplicate_keys_with_new_keys()
        |> AwsSsoConfigGenerator.Util.maybe_load_template()
        |> AwsSsoConfigGenerator.Util.maybe_rename_accounts_and_roles()

      expected_config = %AwsSsoConfigGenerator{
        account_roles: [
          %{
            "accountId" => "333333",
            "roleName" => "ReadOnly",
            "accountIdNew" => "prod",
            "roleNameNew" => "read"
          },
          %{
            "accountId" => "333333",
            "roleName" => "Admin",
            "accountIdNew" => "prod",
            "roleNameNew" => ""
          },
          %{
            "accountId" => "111111",
            "roleName" => "ReadOnly",
            "accountIdNew" => "dev",
            "roleNameNew" => "read"
          },
          %{
            "accountId" => "111111",
            "roleName" => "Admin",
            "accountIdNew" => "dev",
            "roleNameNew" => ""
          },
          %{
            "accountId" => "222222",
            "roleName" => "ReadOnly",
            "accountIdNew" => "uat",
            "roleNameNew" => "read"
          },
          %{
            "accountId" => "222222",
            "roleName" => "Admin",
            "accountIdNew" => "uat",
            "roleNameNew" => ""
          }
        ],
        region: "us-east-1",
        sso_region: "us-west-2",
        start_url: "https://example.com/start/#/",
        template: template,
        template_file: Path.join(File.cwd!(), "test/template.json")
      }

      assert config == expected_config
    end

    test "change_account_for_one_set_and_same_for_role" do
      config = %AwsSsoConfigGenerator{
        account_roles: [
          %{"accountId" => "333333", "roleName" => "ReadOnly"},
          %{"accountId" => "333333", "roleName" => "Admin"},
          %{"accountId" => "111111", "roleName" => "ReadOnly"},
          %{"accountId" => "111111", "roleName" => "Admin"}
        ],
        region: "us-east-1",
        sso_region: "us-west-2",
        start_url: "https://example.com/start/#/",
        template: %{},
        template_file:
          Path.join(File.cwd!(), "test/change_account_for_one_set_and_same_for_role.json")
      }

      config =
        config
        |> AwsSsoConfigGenerator.Util.duplicate_keys_with_new_keys()
        |> AwsSsoConfigGenerator.Util.maybe_load_template()
        |> AwsSsoConfigGenerator.Util.maybe_rename_accounts_and_roles()

      expected_config = %AwsSsoConfigGenerator{
        account_roles: [
          %{
            "accountId" => "333333",
            "roleName" => "ReadOnly",
            "accountIdNew" => "prod",
            "roleNameNew" => "ReadOnly"
          },
          %{
            "accountId" => "333333",
            "roleName" => "Admin",
            "accountIdNew" => "prod",
            "roleNameNew" => ""
          },
          %{
            "accountId" => "111111",
            "roleName" => "ReadOnly",
            "accountIdNew" => "111111",
            "roleNameNew" => "ReadOnly"
          },
          %{
            "accountId" => "111111",
            "roleName" => "Admin",
            "accountIdNew" => "111111",
            "roleNameNew" => ""
          }
        ]
      }

      assert config.account_roles == expected_config.account_roles
    end

    test "update_only_a_role" do
      config = %{
        account_roles: [
          %{"accountId" => "333333", "roleName" => "ReadOnly"},
          %{"accountId" => "333333", "roleName" => "Admin"},
          %{"accountId" => "111111", "roleName" => "ReadOnly"},
          %{"accountId" => "111111", "roleName" => "Admin"}
        ],
        region: "us-east-1",
        sso_region: "us-west-2",
        start_url: "https://example.com/start/#/",
        template: %{"roles" => %{"Admin" => ""}},
        template_file: Path.join(File.cwd!(), "test/update_only_a_role.json")
      }

      config =
        config
        |> AwsSsoConfigGenerator.Util.duplicate_keys_with_new_keys()
        |> AwsSsoConfigGenerator.Util.maybe_load_template()
        |> AwsSsoConfigGenerator.Util.maybe_rename_accounts_and_roles()

      expected_config = %{
        account_roles: [
          %{
            "accountId" => "333333",
            "roleName" => "ReadOnly",
            "accountIdNew" => "333333",
            "roleNameNew" => "ReadOnly"
          },
          %{
            "accountId" => "333333",
            "roleName" => "Admin",
            "accountIdNew" => "333333",
            "roleNameNew" => ""
          },
          %{
            "accountId" => "111111",
            "roleName" => "ReadOnly",
            "accountIdNew" => "111111",
            "roleNameNew" => "ReadOnly"
          },
          %{
            "accountId" => "111111",
            "roleName" => "Admin",
            "accountIdNew" => "111111",
            "roleNameNew" => ""
          }
        ]
      }

      assert config.account_roles == expected_config.account_roles
    end

    test "no-template-file" do
      config = %{
        account_roles: [
          %{"accountId" => "333333", "roleName" => "ReadOnly"},
          %{"accountId" => "333333", "roleName" => "Admin"},
          %{"accountId" => "111111", "roleName" => "ReadOnly"},
          %{"accountId" => "111111", "roleName" => "Admin"}
        ],
        region: "us-east-1",
        sso_region: "us-west-2",
        start_url: "https://example.com/start/#/",
        template: %{},
        template_file: "does-not-exist"
      }

      config =
        config
        |> AwsSsoConfigGenerator.Util.duplicate_keys_with_new_keys()
        |> AwsSsoConfigGenerator.Util.maybe_load_template()
        |> AwsSsoConfigGenerator.Util.maybe_rename_accounts_and_roles()

      expected_config = %{
        account_roles: [
          %{
            "accountId" => "333333",
            "roleName" => "ReadOnly",
            "accountIdNew" => "333333",
            "roleNameNew" => "ReadOnly"
          },
          %{
            "accountId" => "333333",
            "roleName" => "Admin",
            "accountIdNew" => "333333",
            "roleNameNew" => "Admin"
          },
          %{
            "accountId" => "111111",
            "roleName" => "ReadOnly",
            "accountIdNew" => "111111",
            "roleNameNew" => "ReadOnly"
          },
          %{
            "accountId" => "111111",
            "roleName" => "Admin",
            "accountIdNew" => "111111",
            "roleNameNew" => "Admin"
          }
        ]
      }

      assert config.account_roles == expected_config.account_roles
    end

    test "region_sso_region" do
      config = %AwsSsoConfigGenerator{
        account_roles: [
          %{"accountId" => "333333", "roleName" => "ReadOnly"},
          %{"accountId" => "333333", "roleName" => "Admin"}
        ],
        region: "us-east-1",
        sso_region: "us-west-2",
        start_url: "https://example.com/start/#/",
        template: %{},
        template_file: "does-not-exist"
      }

      config =
        config
        |> AwsSsoConfigGenerator.Util.duplicate_keys_with_new_keys()
        |> AwsSsoConfigGenerator.Util.maybe_load_template()
        |> AwsSsoConfigGenerator.Util.maybe_rename_accounts_and_roles()

      # :legacy_iam_identity_center
      regions =
        config
        |> AwsSsoConfigGenerator.Util.generate_config()
        |> Map.get(:legacy_iam_identity_center)
        |> Enum.filter(fn profile -> String.contains?(profile, "region = #{config.region}") end)

      assert length(regions) == 2

      sso_regions =
        config
        |> AwsSsoConfigGenerator.Util.generate_config()
        |> Map.get(:legacy_iam_identity_center)
        |> Enum.filter(fn profile ->
          String.contains?(profile, "sso_region = #{config.sso_region}")
        end)

      assert length(sso_regions) == 2

      # :iam_identity_center
      regions =
        config
        |> AwsSsoConfigGenerator.Util.generate_config()
        |> Map.get(:iam_identity_center)
        |> Enum.filter(fn profile -> String.contains?(profile, "region = #{config.region}") end)

      assert length(regions) == 2

      sso_regions =
        config
        |> AwsSsoConfigGenerator.Util.generate_config()
        |> Map.get(:iam_identity_center)
        |> Enum.filter(fn profile ->
          String.contains?(profile, "sso_region = #{config.sso_region}")
        end)

      assert length(sso_regions) == 1
    end
  end
end
