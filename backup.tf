resource "aws_backup_vault" "management" {
  name     = "${local.name_prefix}vault"
  # kms_key_arn = aws_kms_key.this.arn
}

resource "aws_backup_vault" "backup" {
  provider = aws.backup
  name     = "${local.name_prefix}vault-${data.aws_caller_identity.backup.id}"
  # kms_key_arn = aws_kms_key.this.arn
}

resource "aws_organizations_policy" "backup" {
  for_each = fileset(path.module, "/policies/backup/*.json")

  name        = title(replace(split(".", basename(each.key))[0], "/[-_]+/", " "))
  description = "Policy is managed by pippi.io terraform module."
  type        = "BACKUP_POLICY"
  content = templatefile("${path.module}/${each.value}", {
    mgt_vault   = aws_backup_vault.management.name
    bak_vault   = aws_backup_vault.backup.arn
    regions = join(",", [for region in var.config.enabled_regions : "\"${region}\""])
  })
  tags = local.default_tags
}

# complete policies w default values
# 1w freq for non-prod, 1d for prod
# cross account, cross region (copy_actions)
# create the required backup vaults and IAM roles

# {
#   "plans": {
#     "RDS-plan": {
#       "regions": {
#         "@@assign": [
#           "eu-north-1",
#           "eu-west-1"
#         ]
#       },
#       "rules": {
#         "RDS": {
#           "schedule_expression": {
#             "@@assign": "cron(0 5 ? * 2,5 *)"
#           },
#           "start_backup_window_minutes": {
#             "@@assign": "240"
#           },
#           "complete_backup_window_minutes": {
#             "@@assign": "1440"
#           },
#           "lifecycle": {
#             "move_to_cold_storage_after_days": {
#               "@@assign": "30"
#             },
#             "delete_after_days": {
#               "@@assign": "180"
#             }
#           },
#           "target_backup_vault_name": {
#             "@@assign": "test-vault"
#           },
#           "recovery_point_tags": {
#             "g": {
#               "tag_key": {
#                 "@@assign": "g"
#               },
#               "tag_value": {
#                 "@@assign": "h"
#               }
#             }
#           },
#           "copy_actions": {
#             "arn:aws:backup:eu-central-1:$account:backup-vault:test-vault": {
#               "target_backup_vault_arn": {
#                 "@@assign": "arn:aws:backup:eu-central-1:$account:backup-vault:test-vault"
#               },
#               "lifecycle": {
#                 "delete_after_days": {
#                   "@@assign": "180"
#                 },
#                 "move_to_cold_storage_after_days": {
#                   "@@assign": "60"
#                 }
#               }
#             }
#           },
#           "enable_continuous_backup": {
#             "@@assign": false
#           }
#         }
#       },
#       "backup_plan_tags": {
#         "x": {
#           "tag_key": {
#             "@@assign": "x"
#           },
#           "tag_value": {
#             "@@assign": "y"
#           }
#         }
#       },
#       "selections": {
#         "tags": {
#           "asignee": {
#             "iam_role_arn": {
#               "@@assign": "arn:aws:iam::$account:role/myroles"
#             },
#             "tag_key": {
#               "@@assign": "backup"
#             },
#             "tag_value": {
#               "@@assign": [
#                 "default"
#               ]
#             }
#           }
#         }
#       }
#     }
#   }
# }


