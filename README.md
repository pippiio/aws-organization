# pippiio aws-organization

The _aws-organization_ is a generic [Terraform](https://www.terraform.io/) module within the [pippi.io](https://pippi.io) family, maintained by [Tech Chapter](https://techchapter.com/). The pippi.io modules are build to support common use cases often seen at Tech Chapters clients. They are created with best practices in mind and battle tested at scale. All modules are free and open-source under the Mozilla Public License Version 2.0.

The aws-organization module is made to provision and manage an [AWS Organization](https://aws.amazon.com/organizations/) in common scenarious often seen at Tech Chapters clients. This includes, creating sub accounts, [Service Control Policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html), [SSO (Identity Center)](https://aws.amazon.com/iam/identity-center/) and more.

### Example usage:
```hcl
module "aws_organization" {
  source = "github.com/pippiio/aws-organization?ref=v2.0.1"

  config = {
    enabled_regions = [
      "eu-west-1",
    ]

    break_glass_accounts = ["administrator@example.com"]

    units = {
      security = {
        sso = {
          DevSecOps = ["contributer"]
        }
        accounts = {
          "Log archive"      = { email = "log-archive@example.com" }
          "Security tooling" = { email = "security_tooling@example.com" }
        }
      }

      infrastructure = {
        sso = {
          DevOps    = ["read_only"]
          DevSecOps = ["contributer"]
        }
        accounts = {
          Backup = { email = "backup@example.com" }
          Network = {
            email = "network@example.com"
            sso = {
              DevOps = ["contributer"]
            }
          }
        }
      }

      workloads = {
        sso = {
          DevOps = ["read_only"]
        }
        children = {
          "Non Production" = {
            sso = {
              Developers = ["contributor"]
            }
            accounts = {
              "dev" = {
                create_iam_user = true
                email           = "development@example.com"
              }
              "stg" = {
                email           = "staging@example.com"
                create_iam_user = true
              }
            }
          }
          Production = {
            accounts = {
              "prod" = { email = "jr@example.com" }
            }
          }
        }
      }
    }

    sso = {
      groups = {
        "Developers" = { description = "Development team" }
        "DevOps"     = { description = "DevOps team" }
        "DevSecOps"  = { description = "DevSecOps team" }
        "Finance"    = { description = "Finance team" }
      }

      users = {
        "jd" = {
          full_name                      = "John Doe"
          email                          = "john.doe@example.com"
          groups                         = ["DevOps"]
          management_account_permissions = ["billing"]
        }
      }
    }
  }
}
```