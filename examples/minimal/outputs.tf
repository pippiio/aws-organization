output "organization_id" {
  description = "The id of the AWS Organization."
  value       = module.aws_organization.organization
}

output "accounts" {
  description = "All member accounts with their id, email and organizational unit."
  value       = module.aws_organization.accounts
}

output "break_glass_access" {
  description = "Console sign-in URL and initial passwords for the break glass users."
  value       = module.aws_organization.break_glass_access
  sensitive   = true
}
