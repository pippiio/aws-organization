data "aws_organizations_organization" "organization" {}

data "aws_iam_policy_document" "default_scp" {
  statement {
    sid       = "DenyDisablingCloudtrail"
    effect    = "Deny"
    actions   = ["cloudtrail:StopLogging"]
    resources = ["*"]
  }

  statement {
    sid    = "DenyChangeToASpecificRole"
    effect = "Deny"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePermissionsBoundary",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateRole",
      "iam:UpdateRoleDescription"
    ]
    resources = ["arn:aws:iam::*:role/${local.root_role_name}"]
  }

  statement {
    sid       = "DenyCreateConsoleLogin"
    effect    = "Deny"
    actions   = ["iam:CreateLoginProfile"]
    resources = ["*"]
  }
}

locals {
  default_config = defaults(var.config, {
    units    = ""
    accounts = {}

    permission_sets     = {}
    account_assignments = {}
    policies            = {}
  })

  config = merge(local.default_config, {
    policies = {
      DefaultSCP = {
        content = data.aws_iam_policy_document.default_scp.json
        targets = [{ target_type = "ROOT" }]
      }
    }
  })

  root_role_name = "OrganizationAccountAccessRole"

  master_account_id = tolist(setsubtract(data.aws_organizations_organization.organization.accounts, data.aws_organizations_organization.organization.non_master_accounts))[0].id

  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  inline_policies_map = { for k, ps in local.config.permission_sets : k => ps.inline_policy if ps.inline_policy != null }
  managed_policy_map  = { for k, ps in local.config.permission_sets : k => ps.policy_attachments if ps.policy_attachments != null ? length(ps.policy_attachments) > 0 : false }
  managed_policy_attachments = flatten([
    for ps_name, policy_list in local.managed_policy_map : [
      for policy in policy_list : {
        policy_set = ps_name
        policy_arn = policy
      }
    ]
  ])
  managed_policy_attachments_map = {
    for policy in local.managed_policy_attachments : "${policy.policy_set}.${policy.policy_arn}" => policy
  }

  assignment_map = local.config.account_assignments != null ? {
    for a in local.config.account_assignments :
    format("%v-%v-%v-%v", a.account_id != null ? a.account_id : a.account, substr(a.principal_type, 0, 1), a.principal_name, a.permission_set) => a
  } : {}
  group_list = toset([for mapping in local.config.account_assignments : mapping.principal_name if mapping.principal_type == "GROUP"])
  user_list  = toset([for mapping in local.config.account_assignments : mapping.principal_name if mapping.principal_type == "USER"])

  targets_map = local.config.policies != null ? { for t in flatten([
    for policy_name, policy in local.config.policies : [
      for target_name, target in policy.targets : {
        policy_name = policy_name
        target_name = target_name
        target      = can(target.target) ? target.target : null
        target_type = target.target_type
    }]]) : "${t.policy_name}/${t.target_name}" => t
  } : {}

  cloudtrail_name    = "${var.name_prefix}cloudtrail"
  cloudtrail_s3_name = "${var.name_prefix}cloudtrail"
}