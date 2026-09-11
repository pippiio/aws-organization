output "organization_id" {
  description = "The id of the AWS Organization."
  value       = module.aws_organization.organization
}

output "accounts" {
  description = "All member accounts, including the group permissions assigned directly to each of them."
  value       = module.aws_organization.accounts
}
