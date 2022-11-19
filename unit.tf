resource "aws_organizations_organizational_unit" "this" {
  for_each = setunion(keys(var.config.units), ["security", "infrastructure", "suspended", "workloads"])

  name      = title(replace(each.key, "_", " "))
  parent_id = one(aws_organizations_organization.this.roots).id
  tags = merge(
    local.default_tags,
    try(var.config.units[each.key].tags, {})
  )
}

resource "aws_organizations_organizational_unit" "child" {
  for_each = { for entry in flatten([for parent, unit in var.config.units : [
    for name, child in unit.children : {
      key       = "${parent}/${name}"
      parent_id = aws_organizations_organizational_unit.this[parent].id
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
