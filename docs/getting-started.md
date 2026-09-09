# Getting started

## Prerequisites

- Terraform `~>1.8` and the AWS provider `~>5`.
- An AWS account that is, or is about to become, the **management account** of
  an AWS Organization. The module cannot run from a member account.
- Credentials for that account with permission to manage Organizations, IAM,
  KMS, CloudTrail, S3, SSM and IAM Identity Center.
- **IAM Identity Center enabled manually** in the management account if you
  intend to use `config.sso`. The module reads the existing instance with
  `data "aws_ssoadmin_instances"` and fails if there is none. Enabling it is a
  one-click, one-time action in the console.
- A remote state backend with encryption. The state will contain break glass
  console passwords and, if you use `create_iam_user`, IAM secret access keys.

## Calling the module

```hcl
provider "aws" {
  region = "eu-west-1"
}

module "aws_organization" {
  source = "github.com/pippiio/aws-organization?ref=v4.0.4"

  config = {
    break_glass_accounts       = ["alice.admin", "bob.admin"]
    master_account_email       = "aws@example.com"
    master_account_github_repo = "example-org/aws-organization"
  }
}
```

The module declares its own aliased `provider "aws"` blocks in order to reach
into member accounts. As a consequence the `module` block itself **cannot use
`count`, `for_each` or `depends_on`**.

## The first apply

The module configures providers from values it creates in the same run: the
access key used to build the CloudTrail bucket in the Log archive account, and
the account ids the GitHub OIDC roles assume into. Terraform needs provider
configuration to be known at plan time, so the very first apply of a brand new
organization generally has to be staged:

```console
# 1. The organization, the OU tree, the accounts and the Log archive access key
terraform apply \
  -target=module.aws_organization.aws_organizations_account.this \
  -target=module.aws_organization.aws_iam_access_key.log_archive_user

# 2. Everything else
terraform apply
```

If step 2 still reports that a provider configuration depends on values not
yet known, add the resource it names to the step 1 target list and repeat.
Subsequent applies need no targeting, since the provider inputs are then in
state.

Account creation is slow. Expect several minutes per account, and note that
AWS applies a soft quota on new accounts per day, so creating a large
organization may need to be spread over more than one run.

## Adopting an existing organization

Import the organization before the first apply, otherwise Terraform tries to
create one and AWS rejects it:

```console
terraform import module.aws_organization.aws_organizations_organization.this o-abc123def4
```

Existing organizational units and accounts can be imported the same way. The
resource keys follow the shape `<unit>` or `<unit>/<child>` for units, and
`<unit>/<account>` or `<unit>/<child>/<account>` for accounts:

```console
terraform import 'module.aws_organization.aws_organizations_organizational_unit.parent["security"]' ou-abc1-11111111
terraform import 'module.aws_organization.aws_organizations_account.this["security/Log archive"]' 111122223333
```

Existing accounts must sit in the OU the configuration places them in, and
must already have an `OrganizationAccountAccessRole` the management account can
assume.

## After the apply

1. Read the `break_glass_access` output, sign each user in once, change the
   password and enrol an MFA device. The `Corporate` policy blocks creating
   console logins in member accounts, so these users are the fallback path.
2. Check the `accounts` output for the generated account ids, and the
   `/account/<id>/*` SSM parameters for CI/CD credentials and role arns.
3. Move on to per-account infrastructure by assuming
   `OrganizationAccountAccessRole` or the `GitHubActionsRole-<account>` role.

## Removing things

- Removing an account from `config.units` removes it from the organization but
  does not close it, because the module sets `close_on_deletion = false`. Close the
  account from the console, or move it to the *Suspended* unit first.
- The CloudTrail S3 bucket in the Log archive account has
  `prevent_destroy = true`. Removing it requires editing the module.
- `terraform destroy` on a live organization is not a supported path.
