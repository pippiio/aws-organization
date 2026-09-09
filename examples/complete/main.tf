# Complete configuration.
#
# Exercises every input the module accepts: multiple organizational units with
# children, custom and built in service control policies, approved service
# allow lists, IAM Identity Center groups and users, GitHub OIDC, generated
# service credentials and tagging.

locals {
  common_tags = {
    owner       = "platform-team"
    cost-center = "1234"
  }
}

module "aws_organization" {
  source = "github.com/pippiio/aws-organization?ref=v4.0.4"

  # Prefix for named resources in the management account, such as the
  # CloudTrail trail, its log group and the CloudTrail S3 bucket.
  name_prefix = "acme-"

  # Applied to every resource that supports tags.
  default_tags = local.common_tags

  config = {
    # Regions member accounts may operate in. The Corporate policy denies
    # regional actions everywhere else. Global services are exempt.
    enabled_regions = [
      "eu-west-1",
      "eu-central-1",
    ]

    break_glass_accounts = [
      "alice.admin",
      "bob.admin",
      "carol.admin",
    ]

    master_account_email       = "aws@example.com"
    master_account_github_repo = "example-org/aws-organization"

    backup = {
      # Set to true to leave backup.amazonaws.com out of the organization's
      # trusted service access principals.
      disabled = false
    }

    # Custom service control policies, referenced by their map key from the
    # `scp` list of a unit or child unit. The built in policies `security`,
    # `network` and `suspended` can be referenced without declaring them.
    policies = {
      scp = {
        DenyExpensiveInstances = {
          description = "Blocks the largest EC2 instance families outside of the Exceptions unit."
          tags        = { policy-type = "cost-control" }
          content = jsonencode({
            Version = "2012-10-17"
            Statement = [{
              Sid      = "DenyLargeInstanceTypes"
              Effect   = "Deny"
              Action   = "ec2:RunInstances"
              Resource = "arn:aws:ec2:*:*:instance/*"
              Condition = {
                StringLike = {
                  "ec2:InstanceType" = ["*8xlarge", "*12xlarge", "*16xlarge", "*24xlarge"]
                }
              }
            }]
          })
        }

        RequireImdsv2 = {
          description = "Requires IMDSv2 on newly launched EC2 instances."
          content = jsonencode({
            Version = "2012-10-17"
            Statement = [{
              Sid      = "RequireImdsv2"
              Effect   = "Deny"
              Action   = "ec2:RunInstances"
              Resource = "arn:aws:ec2:*:*:instance/*"
              Condition = {
                StringNotEquals = {
                  "ec2:MetadataHttpTokens" = "required"
                }
              }
            }]
          })
        }
      }
    }

    sso = {
      groups = {
        Developers = { description = "Application developers" }

        DevOps = {
          description                    = "Platform and operations team"
          management_account_permissions = ["read_only"]
        }

        DevSecOps = {
          description                    = "Security engineering team"
          management_account_permissions = ["administrator"]
        }

        Finance = {
          description                    = "Finance team"
          management_account_permissions = ["billing"]
        }
      }

      users = {
        "john.doe" = {
          full_name = "John Doe"
          email     = "john.doe@example.com"
          groups    = ["DevOps", "DevSecOps"]
        }

        "jane.roe" = {
          full_name = "Jane Roe"
          email     = "jane.roe@example.com"
          groups    = ["Developers"]
        }
      }
    }

    units = {
      # The Security unit always exists and always contains the Log archive and
      # Security tooling accounts. Declaring it here only adds to that baseline;
      # supplying an `email` for a mandatory account overrides the generated
      # one.
      security = {
        tags = { criticality = "high" }

        group = {
          DevSecOps = ["administrator"]
          DevOps    = ["read_only"]
        }

        accounts = {
          "Log archive"      = { email = "aws+log-archive@example.com" }
          "Security tooling" = { email = "aws+security-tooling@example.com" }
        }
      }

      # Also always exists, with the mandatory Backup and Network accounts. The
      # Network account is automatically constrained by the built in Network
      # policy.
      infrastructure = {
        group = {
          DevOps = ["administrator"]
        }

        accounts = {
          Backup  = { email = "aws+backup@example.com" }
          Network = { email = "aws+network@example.com" }

          "Shared services" = {
            email  = "aws+shared-services@example.com"
            tags   = { tier = "platform" }
            github = ["example-org/platform"]
          }
        }
      }

      workloads = {
        scp   = ["RequireImdsv2"]
        group = { DevOps = ["contributor"] }

        children = {
          "Non Production" = {
            scp   = ["DenyExpensiveInstances"]
            group = { Developers = ["contributor"] }

            accounts = {
              dev = {
                email           = "aws+dev@example.com"
                create_iam_user = true
                github          = ["example-org/platform"]
              }

              stg = {
                email  = "aws+stg@example.com"
                github = ["example-org/platform"]
              }
            }
          }

          Production = {
            group = { Developers = ["read_only"] }

            accounts = {
              prod = {
                email  = "aws+prod@example.com"
                tags   = { environment = "production" }
                github = ["example-org/platform"]

                group = { Finance = ["billing"] }
                user  = { "john.doe" = ["administrator"] }
              }
            }
          }
        }
      }

      # Personal experimentation accounts, restricted to a short list of
      # services through an automatically generated "ApprovedSandbox" policy.
      sandbox = {
        approved_services = [
          "cloudformation",
          "cloudwatch",
          "dynamodb",
          "ec2",
          "lambda",
          "logs",
          "s3",
        ]

        group = { Developers = ["administrator"] }

        accounts = {
          "Sandbox john.doe" = { email = "aws+sandbox-john@example.com" }
        }
      }

      # Accounts that need to sit outside the Corporate policy, for example
      # while migrating a workload in from another organization. The Corporate
      # attachment intentionally skips this unit, though the policy is also
      # attached at the organization root today, so it is still inherited.
      # See docs/configuration.md#known-quirks.
      exceptions = {
        accounts = {
          "Legacy migration" = { email = "aws+legacy@example.com" }
        }
      }
    }
  }
}
