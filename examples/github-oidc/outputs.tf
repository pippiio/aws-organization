output "accounts" {
  description = "All member accounts. Use the account id to look up the /account/<id>/* SSM parameters holding the OIDC role arn and any generated credentials."
  value       = module.aws_organization.accounts
}

output "organization_role_name" {
  description = "Name of the cross account role that exists in every member account."
  value       = module.aws_organization.organization_role_name
}
