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
