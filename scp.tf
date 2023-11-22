resource "aws_organizations_policy" "organization" {
  name        = "Organization"
  type        = "SERVICE_CONTROL_POLICY"
  description = "Organization wide policy that protects the organization."
  tags        = local.default_tags
  content = replace(templatefile("${path.module}/policies/scp/corporate.json", {
    organization_role_name = local.organization_role_name
    super_admin_role       = local.super_admin_role
    enabled_regions        = join(",", [for region in local.enabled_regions : "\"${region}\""])
  }), "/\\s+/", " ")
}

resource "aws_organizations_policy_attachment" "organization" {
  policy_id = aws_organizations_policy.corporate.id
  target_id = one(aws_organizations_organization.this.roots).id
}

resource "aws_organizations_policy" "corporate" {
  name        = "Corporate"
  type        = "SERVICE_CONTROL_POLICY"
  description = "Organization wide policy that limits regions, denies disabling security services, creating users and public s3 buckets."
  tags        = local.default_tags
  content = replace(templatefile("${path.module}/policies/scp/corporate.json", {
    organization_role_name = local.organization_role_name
    super_admin_role       = local.super_admin_role
    enabled_regions        = join(",", [for region in local.enabled_regions : "\"${region}\""])
  }), "/\\s+/", " ")
}

resource "aws_organizations_policy_attachment" "corporate" {
  for_each = { for key, unit in aws_organizations_organizational_unit.parent : key => unit if !contains(["policy staging", "exceptions"], key) }

  policy_id = aws_organizations_policy.corporate.id
  target_id = each.value.id
}

resource "aws_organizations_policy" "network" {
  name        = "Network"
  type        = "SERVICE_CONTROL_POLICY"
  description = "Enables network related services only for Network account."
  tags        = local.default_tags
  content = replace(templatefile("${path.module}/policies/scp/network.json", {
    organization_role_name = local.organization_role_name
    super_admin_role       = local.super_admin_role
  }), "/\\s+/", " ")
}

resource "aws_organizations_policy_attachment" "network" {
  policy_id = aws_organizations_policy.network.id
  target_id = aws_organizations_account.this["infrastructure/Network"].id
}

resource "aws_organizations_policy" "suspended" {
  name        = "Suspended"
  description = "Denies everything."
  type        = "SERVICE_CONTROL_POLICY"
  tags        = local.default_tags
  content     = replace(file("${path.module}/policies/scp/suspended.json"), "/\\s+/", " ")
}

resource "aws_organizations_policy" "security" {
  name = "Security"
  type = "SERVICE_CONTROL_POLICY"
  tags = local.default_tags
  content = replace(templatefile("${path.module}/policies/scp/security.json", {
    organization_role_name = local.organization_role_name
    super_admin_role       = local.super_admin_role
  }), "/\\s+/", " ")
}

resource "aws_organizations_policy" "approved_only" {
  for_each = { for name, unit in local.unit_tree : name => unit if length(unit.approved_services) > 0 }

  name = replace(title(replace("approved ${each.key}", "_", " ")), " ", "")
  type = "SERVICE_CONTROL_POLICY"
  content = replace(templatefile("${path.module}/policies/scp/approved-only.json", {
    organization_role_name = local.organization_role_name
    super_admin_role       = local.super_admin_role
    approved_services      = join(",", [for service in each.value.approved_services : "\"${service}:*\""])
  }), "/\\s+/", " ")
  tags = merge(
    local.default_tags,
    each.value.tags
  )
}

resource "aws_organizations_policy_attachment" "approved_only" {
  for_each = { for name, unit in local.unit_tree : name => unit if length(unit.approved_services) > 0 }

  policy_id = aws_organizations_policy.approved_only[each.key].id
  target_id = local.units[each.key]
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

resource "aws_organizations_policy_attachment" "this" {
  for_each = { for entry in setunion(
    flatten([
      for parent_unit_name, parent_unit in local.unit_tree : [
        for scp in parent_unit.scp : {
          key  = "${parent_unit_name}#${scp}"
          unit = "${parent_unit_name}"
          scp  = scp
    }]]),
    flatten([
      for parent_unit_name, parent_unit in local.unit_tree : [
        for child_unit_name, child_unit in parent_unit.children : [
          for scp in child_unit.scp : {
            key  = "${parent_unit_name}/${child_unit_name}#${scp}"
            unit = "${parent_unit_name}/${child_unit_name}"
            scp  = scp
    }]]])
  ) : entry.key => entry }

  policy_id = local.scp_policies[each.value.scp]
  target_id = local.units[each.value.unit]
}

locals {
  scp_policies = merge(
    { for name, policy in aws_organizations_policy.this : name => policy.id },
    {
      network   = aws_organizations_policy.network.id
      suspended = aws_organizations_policy.suspended.id
      security  = aws_organizations_policy.security.id
    }
  )
}
