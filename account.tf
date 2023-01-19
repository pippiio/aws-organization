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
    ignore_changes = [role_name]
  }
}

resource "aws_iam_user" "iam_service_user" {
  for_each = { for key, account in local.accounts : key => account if account.create_iam_user }

  name = tostring(aws_organizations_account.this[each.key].id)
  path = "/accounts/"

  tags = local.default_tags
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
