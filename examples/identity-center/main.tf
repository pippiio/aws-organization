# IAM Identity Center (SSO).
#
# IAM Identity Center must already be enabled in the management account before
# applying: the module reads the existing instance, it does not create one.
#
# The module creates four permission sets. Reference them by the keys below in
# a `group` or `user` map:
#
#   administrator  AdministratorAccess                       1 hour sessions
#   contributor    PowerUserAccess + IAM role management    10 hour sessions
#   billing        job-function/Billing                      1 hour sessions
#   read_only      ReadOnlyAccess                            2 hour sessions
#
# Group assignments are inherited down the tree: a group granted on a unit is
# granted on every account below it, and the permission sets of the parent
# unit, the child unit and the account are merged rather than overridden.

module "aws_organization" {
  source = "github.com/pippiio/aws-organization?ref=v4.0.4"

  config = {
    enabled_regions      = ["eu-west-1", "eu-central-1"]
    break_glass_accounts = ["alice.admin", "bob.admin"]

    master_account_email       = "aws@example.com"
    master_account_github_repo = "example-org/aws-organization"

    sso = {
      groups = {
        Developers = {
          description = "Application developers"
        }

        DevOps = {
          description = "Platform and operations team"
          # Permissions on the management account itself.
          management_account_permissions = ["read_only"]
        }

        Finance = {
          description                    = "Finance team"
          management_account_permissions = ["billing"]
        }
      }

      users = {
        # The map key is the Identity Center user name (the sign-in name).
        "john.doe" = {
          # `full_name` is split on the first space into given and family name,
          # so exactly two words are required.
          full_name = "John Doe"
          email     = "john.doe@example.com"
          groups    = ["DevOps"]
        }

        "jane.roe" = {
          full_name = "Jane Roe"
          email     = "jane.roe@example.com"
          groups    = ["Developers", "Finance"]
        }
      }
    }

    units = {
      infrastructure = {
        # Granted on every account in the Infrastructure unit, including the
        # mandatory Backup and Network accounts.
        group = {
          DevOps = ["administrator"]
        }
      }

      workloads = {
        # Inherited by both children below.
        group = {
          DevOps = ["contributor"]
        }

        children = {
          "Non Production" = {
            # Merged with the parent grant: Developers get contributor and
            # DevOps keep contributor on every non production account.
            group = {
              Developers = ["contributor"]
            }

            accounts = {
              dev = { email = "aws+dev@example.com" }
              stg = { email = "aws+stg@example.com" }
            }
          }

          Production = {
            group = {
              Developers = ["read_only"]
            }

            accounts = {
              prod = {
                email = "aws+prod@example.com"

                # Account level grants are added on top of the inherited ones.
                group = {
                  Finance = ["billing"]
                }

                # Direct user assignment, bypassing group membership. The key
                # must match a key in `config.sso.users`.
                user = {
                  "john.doe" = ["administrator"]
                }
              }
            }
          }
        }
      }
    }
  }
}
