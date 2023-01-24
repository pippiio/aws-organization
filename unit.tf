resource "aws_organizations_organizational_unit" "parent" {
  for_each = local.unit_tree

  name      = title(replace(each.key, "_", " "))
  parent_id = one(aws_organizations_organization.this.roots).id
  tags = merge(
    local.default_tags,
    try(var.config.units[each.key].tags, {})
  )
}

resource "aws_organizations_organizational_unit" "child" {
  for_each = { for entry in flatten([for parent, unit in local.unit_tree : [
    for name, child in unit.children : {
      key       = "${parent}/${name}"
      parent_id = aws_organizations_organizational_unit.parent[parent].id
      child     = name
      tags      = child.tags
  }]]) : entry.key => entry }

  name      = title(replace(each.value.child, "_", " "))
  parent_id = each.value.parent_id
  tags = merge(
    local.default_tags,
    each.value.tags
  )
}

locals {
  units = merge(
    { for key, resource in aws_organizations_organizational_unit.parent : key => resource.id },
    { for key, resource in aws_organizations_organizational_unit.child : key => resource.id }
  )
}
