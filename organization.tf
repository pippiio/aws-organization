resource "aws_organizations_organizational_unit" "units" {
  for_each = toset(local.config.units)

  name      = each.value
  parent_id = data.aws_organizations_organization.organization.roots[0].id
}

resource "aws_organizations_account" "accounts" {
  for_each = local.config.accounts

  name      = each.key
  email     = each.value.email
  role_name = local.root_role_name
  parent_id = each.value.unit != null ? aws_organizations_organizational_unit.units[each.value.unit].id : null
}