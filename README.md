# pippiio aws-organization

The _aws-organization_ is a generic [Terraform](https://www.terraform.io/) module within the [pippi.io](https://pippi.io) family, maintained by [Tech Chapter](https://techchapter.com/). The pippi.io modules are build to support common use cases often seen at Tech Chapters clients. They are created with best practices in mind and battle tested at scale. All modules are free and open-source under the Mozilla Public License Version 2.0.

The aws-organization module is made to provision and manage an [AWS Organization](https://aws.amazon.com/organizations/) in common scenarious often seen at Tech Chapters clients. This includes, creating sub accounts, [Service Control Policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html), [SSO (Identity Center)](https://aws.amazon.com/iam/identity-center/) and more.

## Usage

```hcl
provider "aws" {
  region = "eu-west-1"
}

module "aws_organization" {
  source = "github.com/pippiio/aws-organization?ref=v4.0.4"

  config = {
    enabled_regions = ["eu-west-1"]

    break_glass_accounts = ["alice.admin", "bob.admin"]

    master_account_email       = "aws@example.com"
    master_account_github_repo = "example-org/aws-organization"
    backup                     = {}

    sso = {
      groups = {
        Developers = { description = "Application developers" }
        DevOps = {
          description                    = "Platform and operations team"
          management_account_permissions = ["read_only"]
        }
      }

      users = {
        "john.doe" = {
          full_name = "John Doe"
          email     = "john.doe@example.com"
          groups    = ["DevOps"]
        }
      }
    }

    units = {
      workloads = {
        group = { DevOps = ["contributor"] }

        children = {
          "Non Production" = {
            group = { Developers = ["contributor"] }
            accounts = {
              dev = { email = "aws+dev@example.com" }
              stg = { email = "aws+stg@example.com" }
            }
          }

          Production = {
            group = { Developers = ["read_only"] }
            accounts = {
              prod = {
                email  = "aws+prod@example.com"
                github = ["example-org/platform"]
              }
            }
          }
        }
      }
    }
  }
}
```

This produces the following organization, where *Security*, *Infrastructure*,
*Policy Staging*, *Exceptions* and *Suspended* (and their accounts) are part
of the baseline the module always creates:

```text
Root
|-- Security
|   |-- Log archive
|   `-- Security tooling
|-- Infrastructure
|   |-- Backup
|   `-- Network
|-- Policy Staging
|   `-- Policy Stage
|-- Exceptions
|-- Suspended
`-- Workloads
    |-- Non Production
    |   |-- dev
    |   `-- stg
    `-- Production
        `-- prod
```

## Examples

| Example | What it shows |
|---|---|
| [minimal](examples/minimal) | The four required inputs and nothing else |
| [identity-center](examples/identity-center) | Groups, users, permission sets and how grants are inherited down the tree |
| [github-oidc](examples/github-oidc) | CI/CD access to member accounts through OIDC or generated credentials |
| [complete](examples/complete) | Every input, annotated |

## Documentation

| Document | Contents |
|---|---|
| [Getting started](docs/getting-started.md) | Prerequisites, the staged first apply, adopting an existing organization |
| [Architecture](docs/architecture.md) | The unit tree, mandatory accounts, CloudTrail, KMS, break glass and CI/CD access |
| [Configuration reference](docs/configuration.md) | Every field of `var.config`, the outputs, and known quirks |
| [Service control policies](docs/service-control-policies.md) | Built in policies, `approved_services`, custom policies |

## Requirements

| Requirement | Version |
|---|---|
| terraform | `~>1.8` |
| hashicorp/aws | `~>5` |

Run from the AWS Organizations management account. IAM Identity Center must be
enabled in that account before using `config.sso`. Because the module declares
aliased providers internally, the `module` block cannot use `count`,
`for_each` or `depends_on`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `config` | `object` | n/a | See the [configuration reference](docs/configuration.md) |
| `name_prefix` | `string` | `"pippi-"` | Prefix for named resources in the management account |
| `default_tags` | `map(string)` | `{}` | Tags merged into every taggable resource |

## Outputs

| Name | Description |
|---|---|
| `organization` | The organization id |
| `enabled_regions` | The configured `enabled_regions` |
| `accounts` | Every member account with `name`, `email`, `id`, `ou` and directly assigned `permissions` |
| `network_account` | `id` and `assume_role_arn` for the Network account |
| `organization_role_name` | `OrganizationAccountAccessRole` |
| `break_glass_access` | Break glass usernames, generated passwords and console URL. **Sensitive** |

## License

Mozilla Public License Version 2.0. See [LICENSE](LICENSE).
