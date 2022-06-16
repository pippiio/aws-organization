# pippiio aws-organization
Terraform module for deploying AWS Organization resources

## Usage
```hcl
module "organization" {
  source = "github.com/pippiio/aws-organization.git"

  config = {
    cloudtrail_180days_deep_archive = true

    units = ["ops", "config"]

    accounts = {
      stage = {
        email = "admin+stage@pippi.io"
        unit  = "ops"
      },
      prod = {
        email = "admin+prod@pippi.io"
        unit  = "ops"
      },
      config = {
        email = "admin+config@pippi.io"
        unit  = "config"
      }
    },

    permission_sets = {
      AdministratorAccess = {
        description        = "Allow Full Access to the account",
        policy_attachments = [data.aws_iam_policy.AdministratorAccess.arn]
      },
      ViewOnlyAccess = {
        description        = "Allow ViewOnly Access to the account",
        policy_attachments = [data.aws_iam_policy.ViewOnlyAccess.arn]
      },
      Billing = {
        description        = "Allow Billing Access to the account",
        policy_attachments = [data.aws_iam_policy.Billing.arn]
      },
      Contributer = {
        description        = "Allow Contributer Access to the account",
        inline_policy      = data.aws_iam_policy_document.contributer.json
        policy_attachments = [data.aws_iam_policy.PowerUserAccess.arn]
      }
    }

    account_assignments = [
      # === AdministratorAccess to Administrator for all accounts === #
      {
        account_id     = local.master_account_id
        permission_set = "AdministratorAccess",
        principal_type = "GROUP",
        principal_name = "Administrators"
      },
      {
        account        = "stage",
        permission_set = "AdministratorAccess",
        principal_type = "GROUP",
        principal_name = "Administrators"
      },
      {
        account        = "prod",
        permission_set = "AdministratorAccess",
        principal_type = "GROUP",
        principal_name = "Administrators"
      },
      {
        account        = "config",
        permission_set = "AdministratorAccess",
        principal_type = "GROUP",
        principal_name = "Administrators"
      },


      # === Billing to Billing for all accounts === #
      {
        account_id     = local.master_account_id
        permission_set = "Billing",
        principal_type = "GROUP",
        principal_name = "Billing"
      },
      {
        account        = "stage",
        permission_set = "Billing",
        principal_type = "GROUP",
        principal_name = "Billing"
      },
      {
        account        = "prod",
        permission_set = "Billing",
        principal_type = "GROUP",
        principal_name = "Billing"
      },
      {
        account        = "config",
        permission_set = "Billing",
        principal_type = "GROUP",
        principal_name = "Billing"
      },

      # === Contributer to Developer for stage ops accounts === #
      {
        account        = "stage",
        permission_set = "Contributer",
        principal_type = "GROUP",
        principal_name = "Developer"
      },

      # === ViewOnlyAccess to Developer for all ops accounts === #
      {
        account        = "stage",
        permission_set = "ViewOnlyAccess",
        principal_type = "GROUP",
        principal_name = "Developer"
      },
      {
        account        = "prod",
        permission_set = "ViewOnlyAccess",
        principal_type = "GROUP",
        principal_name = "Developer"
      }
    ]
  }
}
```

## Requirements
|Name     |Version |
|---------|--------|
|terraform|>= 1.2.0|
|aws      |~> 4.0  |


## Variables
### config:
|Name                           |Type            |Default|Required|Description|
|-------------------------------|----------------|-------|--------|-----------|
|cloudtrail_180days_deep_archive|bool            |true   |no      |Deep Archive or delete cloudtrail logs after 180 days|
|units                          |list(string)    |nil    |no      |Organization root units|
|accounts                       |map(object({})) |nil    |no      |Organization accounts|
|permission_sets                |map(object({})) |nil    |no      |SSO Permission Sets|
|account_assignments            |list(object({}))|nil    |no      |SSO Account Assignments|
|policies                       |map(object({})) |nil    |no      |Organization SCP Policies|