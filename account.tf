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
