output "organization" {
  value = aws_organizations_organization.this.id
}

output "break_glass_access" {
  value = [for username in var.config.break_glass_accounts : {
    username = username,
    password = aws_iam_user_login_profile.break_glass_access[username].password
    console  = "https://${local.account_id}.signin.aws.amazon.com/console"
  }]
}

output "subaccount_config" {
  value = {
    log_archive_account_id      = aws_organizations_account.this["security/Log archive"].id
    security_tooling_account_id = aws_organizations_account.this["security/Security tooling"].id
    backup_account_id           = aws_organizations_account.this["infrastructure/Backup"].id
    network_account_id          = aws_organizations_account.this["infrastructure/Network"].id

    organization_kms_arn   = aws_kms_key.this.arn
    organization_role_name = local.organization_role_name
    enabled_regions        = var.config.enabled_regions
  }
}
