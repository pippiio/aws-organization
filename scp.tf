resource "aws_organizations_policy" "corporate" {
  name        = "Corporate"
  type        = "SERVICE_CONTROL_POLICY"
  description = "Organization wide policy that protects the organization, limits regions, denies disabling security services, creating users and public s3 buckets."
  content = templatefile("${path.module}/policies/scp/corporate.json", {
    organization_role_name = local.organization_role_name
    super_admin_role       = local.super_admin_role
    enabled_regions        = join(",", [for region in local.enabled_regions : "\"${region}\""])
  })
  tags = local.default_tags
}

resource "aws_organizations_policy_attachment" "corporate" {
  for_each = aws_organizations_organizational_unit.this

  policy_id = aws_organizations_policy.corporate.id
  target_id = each.value.id
}

resource "aws_organizations_policy" "suspended" {
  name        = "Suspended"
  description = "Denies everything."
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${path.module}/policies/scp/suspended.json")
  tags        = local.default_tags
}

resource "aws_organizations_policy_attachment" "suspended" {
  policy_id = aws_organizations_policy.suspended.id
  target_id = aws_organizations_organizational_unit.this["suspended"].id
}

resource "aws_organizations_policy" "security" {
  name    = "Security"
  type    = "SERVICE_CONTROL_POLICY"
  content = file("${path.module}/policies/scp/security.json")
  tags    = local.default_tags
}

resource "aws_organizations_policy_attachment" "security" {
  policy_id = aws_organizations_policy.security.id
  target_id = aws_organizations_organizational_unit.this["security"].id
}

resource "aws_organizations_policy" "approved_only" {
  for_each = { for name, unit in var.config.units : name => unit if length(unit.approved_services) > 0 }

  name = replace(title(replace("approved ${each.key}", "_", " ")), " ", "")
  type = "SERVICE_CONTROL_POLICY"
  content = templatefile("${path.module}/policies/scp/approved-only.json", {
    organization_role_name = local.organization_role_name
    super_admin_role       = local.super_admin_role
    approved_services      = join(",", [for service in each.value.approved_services : "\"${service}:*\""])
  })
  tags = merge(
    local.default_tags,
    each.value.tags
  )
}

resource "aws_organizations_policy_attachment" "approved_only" {
  for_each = { for name, unit in var.config.units : name => unit if length(unit.approved_services) > 0 }

  policy_id = aws_organizations_policy.approved_only[each.key].id
  target_id = aws_organizations_organizational_unit.this[each.key].id
}

resource "aws_organizations_policy" "this" {
  for_each = var.config.policies.scp

  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = each.value.content
  tags = merge(
    local.default_tags,
    each.value.tags
  )
}

resource "aws_organizations_policy_attachment" "unit" {
  for_each = { for entry in flatten([for unit_name, unit in var.config.units : [
    for scp in unit.scp : {
      key  = "${unit_name}/${scp}"
      unit = unit_name
      scp  = scp
  }]]) : entry.key => entry }

  policy_id = aws_organizations_policy.this[each.value.scp].id
  target_id = aws_organizations_organizational_unit.this[each.value.unit].id
}

resource "aws_organizations_policy_attachment" "unit_account" {
  for_each = { for entry in flatten([for unit_name, unit in var.config.units : [
    for account_name, account in unit.accounts : [
      for scp in account.scp : {
        key     = "${unit_name}/${account_name}/${scp}"
        account = "${unit_name}/${account_name}"
        scp     = scp
  }]]]) : entry.key => entry }

  policy_id = aws_organizations_policy.this[each.value.scp].id
  target_id = aws_organizations_account.unit[each.value.account].id
}

resource "aws_organizations_policy_attachment" "child" {
  for_each = { for entry in flatten([for unit_name, unit in var.config.units : [
    for child_name, child in unit.children : [
      for scp in child.scp : {
        key   = "${unit_name}/${child_name}/${scp}"
        child = "${unit_name}/${child_name}"
        scp   = scp
  }]]]) : entry.key => entry }

  policy_id = aws_organizations_policy.this[each.value.scp].id
  target_id = aws_organizations_organizational_unit.child[each.value.child].id
}

resource "aws_organizations_policy_attachment" "child_account" {
  for_each = { for entry in flatten([for unit_name, unit in var.config.units : [
    for child_name, child in unit.children : [
      for account_name, account in child.accounts : [
        for scp in account.scp : {
          key     = "${unit_name}/${child_name}/${account_name}/${scp}"
          account = "${unit_name}/${child_name}/${account_name}"
          scp     = scp
  }]]]]) : entry.key => entry }

  policy_id = aws_organizations_policy.this[each.value.scp].id
  target_id = aws_organizations_account.child[each.value.account].id
}
