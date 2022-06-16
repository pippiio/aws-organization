resource "aws_organizations_policy" "this" {
  for_each = local.config.policies != null ? local.config.policies : {}

  name    = each.key
  content = each.value.content
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = local.targets_map

  policy_id = aws_organizations_policy.this[each.value.policy_name].id
  target_id = each.value.target_type == "ROOT" ? data.aws_organizations_organization.organization.roots[0].id : each.value.target_type == "UNIT" ? aws_organizations_organizational_unit.units[each.value.target].id : aws_organizations_account.accounts[each.value.target].id
}