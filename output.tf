output "organization" {
  value = aws_organizations_organization.this.id
}

output "enabled_regions" {
  value = var.config.enabled_regions
}

output "break_glass_access" {
  value = [for username in var.config.break_glass_accounts : {
    username = username,
    password = aws_iam_user_login_profile.break_glass_access[username].password
    console  = "https://${local.account_id}.signin.aws.amazon.com/console"
  }]
}

output "organization_role_name" {
  value = local.organization_role_name
}

output "accounts" {
  value = [for key, account in aws_organizations_account.this : {
    name                   = account.name
    email                  = account.email
    id                     = account.id
    ou                     = replace(key, "/${account.name}$/", "")
    permissions            = local.accounts[key].sso
    access_key             = try(aws_iam_access_key.iam_service_user[key].id, null)
    secret_key             = try(aws_iam_access_key.iam_service_user[key].secret, null)
    organization_role_name = "arn:aws:iam::${account.id}:role/${local.organization_role_name}"
  }]
}

output "network_account" {
  value = {
    id              = aws_organizations_account.this["infrastructure/Network"].id
    assume_role_arn = format("arn:aws:iam::%s:role/%s", aws_organizations_account.this["infrastructure/Network"].id, local.organization_role_name)
  }
}
