locals {
  master_account_email = split("@", aws_organizations_organization.this.master_account_email)
  email_template       = "${local.master_account_email[0]}+%s@${local.master_account_email[1]}"
}

resource "aws_organizations_account" "this" {
  for_each = local.accounts

  name              = each.value.name
  email             = each.value.email
  role_name         = local.organization_role_name
  parent_id         = local.units[each.value.unit_name]
  tags              = merge(local.default_tags, each.value.tags)
  close_on_deletion = false
  create_govcloud   = false

  lifecycle {
    ignore_changes = [
      name,
      email,
      role_name,
    ]
  }
}

resource "aws_iam_user" "iam_service_user" {
  for_each = { for key, account in local.accounts : key => account if account.create_iam_user }

  name = tostring(aws_organizations_account.this[each.key].id)
  path = "/accounts/"

  tags = local.default_tags
}

resource "aws_ssm_parameter" "iam_service_user_access_key_id" {
  for_each = { for key, account in local.accounts :
    key => account
    if account.create_iam_user
  }

  name        = "/account/${aws_organizations_account.this[each.key].id}/aws_access_key_id"
  description = format("AWS access key id to assume %s organization admin role", aws_organizations_account.this[each.key].id)
  type        = "String"
  value       = aws_iam_access_key.iam_service_user[each.key].id
  tags        = local.default_tags
}

resource "aws_ssm_parameter" "iam_service_user_secret_access_key" {
  for_each = { for key, account in local.accounts :
    key => account
    if account.create_iam_user
  }

  name        = "/account/${aws_organizations_account.this[each.key].id}/aws_secret_access_key"
  description = format("AWS access key secret to assume %s organization admin role", aws_organizations_account.this[each.key].id)
  type        = "SecureString"
  key_id      = aws_kms_key.this.arn
  value       = aws_iam_access_key.iam_service_user[each.key].secret
  tags        = local.default_tags
}

resource "aws_ssm_parameter" "iam_service_user_assume_role_arn" {
  for_each = { for key, account in local.accounts :
    key => account
    if account.create_iam_user
  }

  name        = "/account/${aws_organizations_account.this[each.key].id}/aws_assume_role_arn"
  description = format("The AWS role to assume in account %s", aws_organizations_account.this[each.key].id)
  type        = "String"
  value       = format(local.organization_role_arn_template, aws_organizations_account.this[each.key].id)
  tags        = local.default_tags
}

resource "aws_iam_access_key" "iam_service_user" {
  for_each = { for key, account in local.accounts : key => account if account.create_iam_user }

  user = aws_iam_user.iam_service_user[each.key].name
}

resource "aws_iam_user_policy" "iam_service_user" {
  for_each = { for key, account in local.accounts : key => account if account.create_iam_user }

  name   = "AssumeRole"
  user   = aws_iam_user.iam_service_user[each.key].name
  policy = data.aws_iam_policy_document.iam_service_user[each.key].json
}

data "aws_iam_policy_document" "iam_service_user" {
  for_each = { for key, account in local.accounts : key => account if account.create_iam_user }

  statement {
    sid       = "AllowAssumeRole"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${aws_iam_user.iam_service_user[each.key].name}:role/${local.organization_role_name}"]
  }
}
