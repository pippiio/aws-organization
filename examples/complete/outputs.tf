output "organization_id" {
  description = "The id of the AWS Organization."
  value       = module.aws_organization.organization
}

output "enabled_regions" {
  description = "Regions member accounts are allowed to operate in."
  value       = module.aws_organization.enabled_regions
}

output "accounts" {
  description = "All member accounts with their id, email, organizational unit and directly assigned permissions."
  value       = module.aws_organization.accounts
}

output "network_account" {
  description = "Id and cross account role arn of the Network account, for use by a networking module."
  value       = module.aws_organization.network_account
}

output "organization_role_name" {
  description = "Name of the cross account role that exists in every member account."
  value       = module.aws_organization.organization_role_name
}

output "break_glass_access" {
  description = "Console sign-in URL and initial passwords for the break glass users."
  value       = module.aws_organization.break_glass_access
  sensitive   = true
}
