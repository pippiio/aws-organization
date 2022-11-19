locals {
  enable_sso = length(local.sso_groups) > 0 ? 1 : 0
  sso_groups = setunion(
    
    flatten([for unit in values(var.config.units) : [for group in keys(unit.sso) : group]]),
    flatten([for unit in values(var.config.units) : [for account in values(unit.accounts) : [for group in keys(account.sso) : group]]]),
    flatten([for unit in values(var.config.units) : [for child in values(unit.children) : [for group in keys(child.sso) : group]]]),
    flatten([for unit in values(var.config.units) : [for child in values(unit.children) : [for account in keys(child.accounts) : [for group in keys(account.sso) : group]]]]),
  )
  permission_sets = length(local.sso_groups) > 0 ? merge({
    administrator = one(aws_ssoadmin_permission_set.administrator).id
    contributer   = one(aws_ssoadmin_permission_set.contributer).id
    read_only     = one(aws_ssoadmin_permission_set.read_only).id
  }) : {}
}

data "aws_ssoadmin_instances" "this" {
  count = local.enable_sso
}

data "aws_identitystore_group" "this" {
  for_each = local.sso_groups

  identity_store_id = one(one(data.aws_ssoadmin_instances.this).identity_store_ids)

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.key
    }
  }
}

resource "aws_identitystore_group" "this" {
  display_name      = "Example group"
  description       = "Example description"
  identity_store_id = tolist(data.aws_ssoadmin_instances.example.identity_store_ids)[0]
}


output "debug" {
  value = local.sso_groups
}

# resource "aws_identitystore_group" "this" {
#   display_name      = "Example group"
#   description       = "Example description"
#   identity_store_id = tolist(data.aws_ssoadmin_instances.example.identity_store_ids)[0]
# }

resource "aws_ssoadmin_permission_set" "administrator" {
  count = local.enable_sso

  name             = local.super_admin_role
  description      = "Provides full access to AWS services and resources (only limited by scp)."
  instance_arn     = one(one(data.aws_ssoadmin_instances.this).arns)
  relay_state      = "https://${local.region_name}.console.aws.amazon.com/console/"
  session_duration = "PT1H"
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator" {
  count = local.enable_sso

  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = one(aws_ssoadmin_permission_set.administrator).arn
}

resource "aws_ssoadmin_permission_set" "contributer" {
  count = local.enable_sso

  name             = "Contributer"
  description      = "Provides power user access to AWS services and resources (only limited by scp)."
  instance_arn     = one(one(data.aws_ssoadmin_instances.this).arns)
  relay_state      = "https://${local.region_name}.console.aws.amazon.com/console/"
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "contributer" {
  count = local.enable_sso

  managed_policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = one(aws_ssoadmin_permission_set.contributer).arn
}

resource "aws_ssoadmin_permission_set" "read_only" {
  count = local.enable_sso

  name             = "ReadOnly"
  description      = "Provides read only access to AWS services and resources (only limited by scp)."
  instance_arn     = one(one(data.aws_ssoadmin_instances.this).arns)
  relay_state      = "https://${local.region_name}.console.aws.amazon.com/console/"
  session_duration = "PT2H"
}

resource "aws_ssoadmin_managed_policy_attachment" "read_only" {
  count = local.enable_sso

  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = one(aws_ssoadmin_permission_set.read_only).arn
}

resource "aws_ssoadmin_account_assignment" "unit" {
  for_each = { for entry in toset(flatten([
    for unit_name, unit in var.config.units : [
      for group, permissions in unit.sso : [
        for account_name, account in unit.accounts : [
          for permission in permissions : {
            key        = "${unit_name}/${account_name}/${group}/${permission}"
            account    = "${unit_name}/${account_name}"
            group      = group
            permission = permission
  }]]]])) : entry.key => entry }

  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = local.permission_sets[each.value.permission]
  principal_id       = data.aws_identitystore_group.this[each.value.group].id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.unit[each.value.account].id
}

resource "aws_ssoadmin_account_assignment" "unit_account" {
  for_each = { for entry in toset(flatten([
    for unit_name, unit in var.config.units : [
      for account_name, account in unit.accounts : [
        for group, permissions in account.sso : [
          for permission in permissions : {
            key        = "${unit_name}/${account_name}/${group}/${permission}"
            account    = "${unit_name}/${account_name}"
            group      = group
            permission = permission
  }]]]])) : entry.key => entry }

  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = local.permission_sets[each.value.permission]
  principal_id       = data.aws_identitystore_group.this[each.value.group].id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.unit[each.value.account].id
}

resource "aws_ssoadmin_account_assignment" "child" {
  for_each = { for entry in toset(flatten([
    for unit_name, unit in var.config.units : [
      for child_name, child in unit.children : [
        for account_name, account in child.accounts : [
          for group, permissions in child.sso : [
            for permission in permissions : {
              key        = "${unit_name}/${child_name}/${group}/${permission}"
              account    = "${unit_name}/${account_name}"
              group      = group
              permission = permission
  }]]]]])) : entry.key => entry }

  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = local.permission_sets[each.value.permission]
  principal_id       = data.aws_identitystore_group.this[each.value.group].id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.unit[each.value.account].id
}

resource "aws_ssoadmin_account_assignment" "child_account" {
  for_each = { for entry in toset(flatten([
    for unit_name, unit in var.config.units : [
      for child_name, child in unit.children : [
        for account_name, account in child.accounts : [
          for group, permissions in account.sso : [
            for permission in permissions : {
              key        = "${unit_name}/${child_name}/${group}/${permission}"
              account    = "${unit_name}/${account_name}"
              group      = group
              permission = permission
  }]]]]])) : entry.key => entry }

  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = local.permission_sets[each.value.permission]
  principal_id       = data.aws_identitystore_group.this[each.value.group].id
  principal_type     = "GROUP"
  target_id          = aws_organizations_account.unit[each.value.account].id
}
