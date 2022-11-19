

# resource "aws_organizations_policy" "scp" {
#   for_each = fileset(path.module, "/policies/scp/*.json")

#   name    = title(replace(split(".", basename(each.key))[0], "/[-_]+/", " "))
#   type    = "SERVICE_CONTROL_POLICY"
#   content = file("${path.module}/${each.value}")
#   tags    = local.default_tags
# }

# resource "aws_organizations_policy" "tag" {
#   for_each = fileset(path.module, "/policies/tag/*.json")

#   name    = title(replace(split(".", basename(each.key))[0], "/[-_]+/", " "))
#   type    = "TAG_POLICY"
#   content = file("${path.module}/${each.value}")
#   tags    = local.default_tags
# }

# resource "aws_organizations_policy_attachment" "aws" {
#   # aws managed base policy is deployed on all units to avoid MIN_POLICY_TYPE_ATTACHMENT_LIMIT_EXCEEDED issue
#   for_each = local.aws_organizations_organizational_unit

#   policy_id = "p-FullAWSAccess"
#   target_id = each.value.id
# }
