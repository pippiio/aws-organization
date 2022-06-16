data "aws_ssoadmin_instances" "this" {}

# === Create Permission Sets === #
resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.config.permission_sets

  name             = each.key
  description      = each.value.description
  instance_arn     = local.sso_instance_arn
  relay_state      = each.value.relay_state
  session_duration = each.value.session_duration
}

# === Attach Inline Policies === #
resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = local.inline_policies_map

  inline_policy      = each.value
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
}

# === Attach Managed Policies === #
resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = local.managed_policy_attachments_map

  managed_policy_arn = each.value.policy_arn
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.policy_set].arn
}

# === Find Identity Store Groups === #
data "aws_identitystore_group" "this" {
  for_each          = local.group_list
  identity_store_id = local.identity_store_id

  filter {
    attribute_path  = "DisplayName"
    attribute_value = each.key
  }
}

# === Find Identity Store Users === #
data "aws_identitystore_user" "this" {
  for_each          = local.user_list
  identity_store_id = local.identity_store_id

  filter {
    attribute_path  = "UserName"
    attribute_value = each.key
  }
}

# === Assign Permission Set to Group or User per account === #
resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.assignment_map

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn

  principal_id   = each.value.principal_type == "GROUP" ? data.aws_identitystore_group.this[each.value.principal_name].id : data.aws_identitystore_user.this[each.value.principal_name].id
  principal_type = each.value.principal_type

  target_id   = each.value.account_id != null ? each.value.account_id : aws_organizations_account.accounts[each.value.account].id
  target_type = "AWS_ACCOUNT"
}