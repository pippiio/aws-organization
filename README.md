# pippiio aws-organization
Terraform module for deploying AWS Organization resources

## Usage
```hcl
module "organization" {
  source = "git@github.com:efio-dk/code-as-data//modules/aws/organization"

  config = {
    units                           = tolist(local.units)
    cloudtrail_180days_deep_archive = true
    cloudtrail_name                 = "elucid-cloudtrail"
    cloudtrail_s3_name              = "elucid-cloudtrail"

    accounts = {
      stage = {
        email = "${local.root_email}+aws-stage@${local.root_domain}"
        unit  = local.units_map.ops
      },
      prod = {
        email = "${local.root_email}+aws-prod@${local.root_domain}"
        unit  = local.units_map.ops
      },
      config = {
        email = "${local.root_email}+aws-config@${local.root_domain}"
        unit  = local.units_map.config
      },
      backup = {
        email = "${local.root_email}+aws-backup@${local.root_domain}"
        unit  = local.units_map.admin
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
        account        = local.accounts_map.stage,
        permission_set = "AdministratorAccess",
        principal_type = "GROUP",
        principal_name = "Administrators"
      },
      {
        account        = local.accounts_map.prod,
        permission_set = "AdministratorAccess",
        principal_type = "GROUP",
        principal_name = "Administrators"
      },
      {
        account        = local.accounts_map.config,
        permission_set = "AdministratorAccess",
        principal_type = "GROUP",
        principal_name = "Administrators"
      },
      {
        account        = local.accounts_map.backup,
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
        account        = local.accounts_map.stage,
        permission_set = "Billing",
        principal_type = "GROUP",
        principal_name = "Billing"
      },
      {
        account        = local.accounts_map.prod,
        permission_set = "Billing",
        principal_type = "GROUP",
        principal_name = "Billing"
      },
      {
        account        = local.accounts_map.config,
        permission_set = "Billing",
        principal_type = "GROUP",
        principal_name = "Billing"
      },
      {
        account        = local.accounts_map.backup,
        permission_set = "Billing",
        principal_type = "GROUP",
        principal_name = "Billing"
      },

      # === Contributer to Developer for stage ops accounts === #
      {
        account        = local.accounts_map.stage,
        permission_set = "Contributer",
        principal_type = "GROUP",
        principal_name = "Developer"
      },

      # === ViewOnlyAccess to Developer for all ops accounts === #
      {
        account        = local.accounts_map.stage,
        permission_set = "ViewOnlyAccess",
        principal_type = "GROUP",
        principal_name = "Developer"
      },
      {
        account        = local.accounts_map.prod,
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
|Name                           |Type        |Default|Required|Description|
|-------------------------------|------------|-------|--------|-----------|
|cloudtrail_180days_deep_archive|bool        |true   |no      |Id of VPC to deploy to|
|cloudtrail_name                |string      |nil    |yes     |Ids of subnets to deploy to|
|cloudtrail_s3_name             |string      |1.22   |no      |Version of EKS cluster|
|worker_node_count   |number      |nil    |yes     |Count of worker nodes to deploy|
|worker_instance_type|string      |nil    |yes     |Instance type of worker nodes|
|worker_volume_size  |number      |nil    |yes     |Volume size of worker nodes|
|api_allowed_ips     |list(string)|nil    |no      |Allowed IP's to communicate with cluster API|
|addons              |list(string)|nil    |no      |AWS EKS Addons to install on cluster|