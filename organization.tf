resource "aws_organizations_organization" "this" {
  feature_set = "ALL"
  enabled_policy_types = [
    "BACKUP_POLICY",
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]

  aws_service_access_principals = compact([
    "cloudtrail.amazonaws.com",
    "account.amazonaws.com",
    try(var.config.backup.disabled, false) ? null : "backup.amazonaws.com",
    try(var.config.sso.disabled, false) ? null : "sso.amazonaws.com",
  ])

}

data "aws_organizations_organization" "this" {
  depends_on = [
    aws_organizations_account.this,
  ]
}
