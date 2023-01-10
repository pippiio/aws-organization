locals {
  enable_sso = var.config.sso != null ? 1 : 0
  sso_groups = local.enable_sso == 1 ? var.config.sso.groups : {}
  sso_users  = local.enable_sso == 1 ? var.config.sso.users : {}
  permission_sets = local.enable_sso == 1 ? merge({
    administrator   = one(aws_ssoadmin_permission_set.administrator).arn
    contributer     = one(aws_ssoadmin_permission_set.contributer).arn
    read_only       = one(aws_ssoadmin_permission_set.read_only).arn
    release_manager = one(aws_ssoadmin_permission_set.release_manager).arn
  }) : {}
}

data "aws_ssoadmin_instances" "this" {
  count = local.enable_sso
}

resource "aws_identitystore_group" "this" {
  for_each = local.sso_groups

  display_name      = each.key
  description       = each.value.description
  identity_store_id = one(one(data.aws_ssoadmin_instances.this).identity_store_ids)
}

resource "aws_identitystore_user" "this" {
  for_each = local.sso_users

  identity_store_id = one(one(data.aws_ssoadmin_instances.this).identity_store_ids)
  user_name         = each.key
  display_name      = lower(split(" ", each.value.full_name)[0])

  name {
    given_name  = split(" ", each.value.full_name)[0]
    family_name = split(" ", each.value.full_name)[1]
  }

  emails {
    value = each.value.email
  }
}

resource "aws_identitystore_group_membership" "this" {
  for_each = { for entry in flatten([for username, user in local.sso_users : [
    for group in user.groups : {
      key   = "${username}/${group}"
      user  = username
      group = group
  }]]) : entry.key => entry }

  identity_store_id = one(one(data.aws_ssoadmin_instances.this).identity_store_ids)
  group_id          = aws_identitystore_group.this[each.value.group].group_id
  member_id         = aws_identitystore_user.this[each.value.user].user_id
}

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

resource "aws_ssoadmin_permission_set" "release_manager" {
  count = local.enable_sso

  name             = "ReleaseManager"
  description      = "Provides limited write access to AWS services and resources commonly used by release managers (only limited by scp)."
  instance_arn     = one(one(data.aws_ssoadmin_instances.this).arns)
  relay_state      = "https://${local.region_name}.console.aws.amazon.com/console/"
  session_duration = "PT2H"
}

resource "aws_ssoadmin_managed_policy_attachment" "release_manager" {
  count = local.enable_sso

  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = one(aws_ssoadmin_permission_set.release_manager).arn
}

data "aws_iam_policy_document" "release_manager" {
  statement {
    resources = ["*"]
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:PutObject",
      "autoscaling:CancelInstanceRefresh",
      "autoscaling:DetachInstances",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:AttachInstances",
      "cloudfront:CreateInvalidation"
    ]
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "release_manager" {
  count = local.enable_sso

  inline_policy      = data.aws_iam_policy_document.release_manager.json
  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = one(aws_ssoadmin_permission_set.release_manager).arn
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
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.this[each.value.group].group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = aws_organizations_account.unit[each.value.account].id
}

# resource "aws_ssoadmin_account_assignment" "unit_account" {
#   for_each = { for entry in toset(flatten([
#     for unit_name, unit in var.config.units : [
#       for account_name, account in unit.accounts : [
#         for group, permissions in account.sso : [
#           for permission in permissions : {
#             key        = "${unit_name}/${account_name}/${group}/${permission}"
#             account    = "${unit_name}/${account_name}"
#             group      = group
#             permission = permission
#   }]]]])) : entry.key => entry }

#   instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
#   permission_set_arn = local.permission_sets[each.value.permission]
#   principal_id       = data.aws_identitystore_group.this[each.value.group].id
#   principal_type     = "GROUP"
#   target_id          = aws_organizations_account.unit[each.value.account].id
# }

resource "aws_ssoadmin_account_assignment" "child" {
  for_each = { for entry in toset(flatten([
    for unit_name, unit in var.config.units : [
      for child_name, child in unit.children : [
        for account_name, account in child.accounts : [
          for group, permissions in child.sso : [
            for permission in permissions : {
              key        = "${unit_name}/${child_name}/${account_name}/${group}/${permission}"
              account    = "${unit_name}/${child_name}/${account_name}"
              group      = group
              permission = permission
  }]]]]])) : entry.key => entry }

  instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
  permission_set_arn = local.permission_sets[each.value.permission]
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.this[each.value.group].group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = aws_organizations_account.child[each.value.account].id
}

# resource "aws_ssoadmin_account_assignment" "child_account" {
#   for_each = { for entry in toset(flatten([
#     for unit_name, unit in var.config.units : [
#       for child_name, child in unit.children : [
#         for account_name, account in child.accounts : [
#           for group, permissions in account.sso : [
#             for permission in permissions : {
#               key        = "${unit_name}/${child_name}/${group}/${permission}"
#               account    = "${unit_name}/${account_name}"
#               group      = group
#               permission = permission
#   }]]]]])) : entry.key => entry }

#   instance_arn       = one(one(data.aws_ssoadmin_instances.this).arns)
#   permission_set_arn = local.permission_sets[each.value.permission]
#   principal_id       = data.aws_identitystore_group.this[each.value.group].id
#   principal_type     = "GROUP"
#   target_id          = aws_organizations_account.child[each.value.account].id
# }
