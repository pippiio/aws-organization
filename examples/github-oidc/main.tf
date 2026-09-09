# CI/CD access to member accounts.
#
# Two mechanisms are available, and they can be combined on the same account:
#
#   github          - creates a GitHub OIDC provider and an
#                     "GitHubActionsRole-<account>" role with
#                     AdministratorAccess inside the member account, trusted by
#                     the listed "<org>/<repo>" repositories on any ref. The
#                     role arn is written to the management account parameter
#                     /account/<account id>/aws_oidc_assume_role_arn.
#
#   create_iam_user - creates a long lived IAM user in the *management*
#                     account, named after the member account id, that may only
#                     assume that account's OrganizationAccountAccessRole. The
#                     access key id, secret access key and role arn are written
#                     to /account/<account id>/* parameters, with the secret
#                     encrypted using the module's KMS key. Prefer `github`
#                     where possible; use this for tooling that cannot use
#                     OIDC.
#
# The member account roles are created through provider configurations that
# assume OrganizationAccountAccessRole in each account, so the account must
# exist before its role can be planned. See docs/getting-started.md for the
# two phase apply this implies.

module "aws_organization" {
  source = "github.com/pippiio/aws-organization?ref=v4.0.4"

  config = {
    enabled_regions      = ["eu-west-1"]
    break_glass_accounts = ["alice.admin", "bob.admin"]

    master_account_email = "aws@example.com"

    # Repository allowed to assume the OIDC role in the management account,
    # typically the repository holding this Terraform configuration.
    master_account_github_repo = "example-org/aws-organization"

    backup = {}

    units = {
      workloads = {
        children = {
          "Non Production" = {
            accounts = {
              dev = {
                email = "aws+dev@example.com"

                # Any workflow in either repository can assume
                # GitHubActionsRole-dev in this account.
                github = [
                  "example-org/platform",
                  "example-org/frontend",
                ]
              }
            }
          }

          Production = {
            accounts = {
              prod = {
                email  = "aws+prod@example.com"
                github = ["example-org/platform"]

                # Static credentials in addition to OIDC, for a legacy
                # deployment tool.
                create_iam_user = true
              }
            }
          }
        }
      }
    }
  }
}
