locals {
  master_account_email = split("@", aws_organizations_organization.this.master_account_email)
  email_template       = "${local.master_account_email[0]}+%s@${local.master_account_email[1]}"
}

resource "aws_organizations_account" "log_archive" {
  name              = "Log archive"
  email             = try(var.config.units["infrastructure"].accounts["Log archive"].email, format(local.email_template, "log_archive"))
  role_name         = local.organization_role_name
  parent_id         = aws_organizations_organizational_unit.this["security"].id
  tags              = local.default_tags
  close_on_deletion = false
  create_govcloud   = false

  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_organizations_account" "security_tooling" {
  count = 0

  name              = "Security tooling"
  email             = try(var.config.units["infrastructure"].accounts["Security tooling"].email, format(local.email_template, "security_tooling"))
  role_name         = local.organization_role_name
  parent_id         = aws_organizations_organizational_unit.this["security"].id
  tags              = local.default_tags
  close_on_deletion = false
  create_govcloud   = false

  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_organizations_account" "backup" {
  name              = "Backup"
  email             = try(var.config.units["infrastructure"].accounts["Backup"].email, format(local.email_template, "backup"))
  role_name         = local.organization_role_name
  parent_id         = aws_organizations_organizational_unit.this["infrastructure"].id
  tags              = local.default_tags
  close_on_deletion = false
  create_govcloud   = false

  lifecycle {
    ignore_changes = [
      role_name,
      email
    ]
  }
}

resource "aws_organizations_account" "network" {
  count = 0

  name              = "Network"
  email             = try(var.config.units["infrastructure"].accounts["Network"].email, format(local.email_template, "network"))
  role_name         = local.organization_role_name
  parent_id         = aws_organizations_organizational_unit.this["infrastructure"].id
  tags              = local.default_tags
  close_on_deletion = false
  create_govcloud   = false

  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_organizations_account" "unit" {
  for_each = { for entry in flatten([for unit_name, unit in var.config.units : [
    for account_name, account in unit.accounts : {
      key       = "${unit_name}/${account_name}"
      parent_id = aws_organizations_organizational_unit.this[unit_name].id
      name      = account_name
      account   = account
  }]]) : entry.key => entry }

  name              = each.value.name
  email             = each.value.account.email
  role_name         = local.organization_role_name
  parent_id         = each.value.parent_id
  tags              = merge(local.default_tags, each.value.account.tags)
  close_on_deletion = false
  create_govcloud   = false

  lifecycle {
    ignore_changes = [role_name]
  }
}

resource "aws_organizations_account" "child" {
  for_each = { for entry in flatten([for unit_name, unit in var.config.units : [
    for child_name, child in unit.children : [
      for account_name, account in child.accounts : {
        key       = "${unit_name}/${child_name}/${account_name}"
        parent_id = aws_organizations_organizational_unit.child["${unit_name}/${child_name}"].id
        name      = account_name
        account   = account
  }]]]) : entry.key => entry }

  name              = each.value.name
  email             = each.value.account.email
  role_name         = local.organization_role_name
  parent_id         = each.value.parent_id
  tags              = merge(local.default_tags, each.value.account.tags)
  close_on_deletion = false
  create_govcloud   = false

  lifecycle {
    ignore_changes = [role_name]
  }
}
