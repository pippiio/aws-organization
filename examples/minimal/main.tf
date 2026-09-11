# Minimal configuration.
#
# Only the three required inputs are set. The module still provisions the full
# baseline: the Security, Infrastructure, Policy Staging, Exceptions and
# Suspended organizational units with their mandatory accounts, the default
# Workloads unit with Production / Non Production children, an organization
# CloudTrail, the KMS CMK, the Corporate service control policy and a GitHub
# OIDC role in the management account.
#
# IAM Identity Center is not configured here (`config.sso` is omitted), so no
# permission sets, groups or users are created.

module "aws_organization" {
  source = "github.com/pippiio/aws-organization?ref=v4.0.4"

  config = {
    # Consoles users that keep access when Identity Center is unavailable.
    # Between two and four accounts is recommended; at least one is required.
    break_glass_accounts = [
      "alice.admin",
      "bob.admin",
    ]

    # Base address for the generated member account emails. The local part is
    # extended with a "+<account>" suffix, e.g. aws+log_archive@example.com.
    master_account_email = "aws@example.com"

    # "<org>/<repo>" allowed to assume the management account OIDC role.
    master_account_github_repo = "example-org/aws-organization"
  }
}
