variable "config" {
  type = object({
    enabled_regions      = optional(set(string), [])
    break_glass_accounts = set(string)

    units = optional(map(object({
      tags              = optional(map(string), {})
      approved_services = optional(set(string), [])      // List of iam actions to allow
      scp               = optional(set(string), [])      // scp names
      group             = optional(map(set(string)), {}) // key = group, value = permission_set
      accounts = optional(map(object({                   // key = name
        email           = string
        tags            = optional(map(string), {})
        scp             = optional(set(string), [])      // scp names
        group           = optional(map(set(string)), {}) // key = group, value = permission_set
        user            = optional(map(set(string)), {}) // key = user, value = permission_set
        create_iam_user = optional(bool, false)
      })), {})

      children = optional(map(object({ // key = name
        tags  = optional(map(string), {})
        scp   = optional(set(string), [])      // scp names
        group = optional(map(set(string)), {}) // key = group, value = permission_set
        accounts = optional(map(object({       // key = name
          email           = string
          tags            = optional(map(string), {})
          scp             = optional(set(string), [])      // scp names
          group           = optional(map(set(string)), {}) // key = group, value = permission_set
          user            = optional(map(set(string)), {}) // key = user, value = permission_set
          create_iam_user = optional(bool, false)
        })), {})
      })), {})
      })), {
      "workloads" : {
        "children" : {
          "Production" : {}
          "Non Production" : {}
        }
      }
    })

    policies = optional(object({
      scp = optional(map(object({
        content     = string
        description = string
        tags        = optional(map(string), {})
      })), {})

      # tag = optional(map(object({})))
      # backup = optional(map(object({})))
    }), {})

    sso = optional(object({
      groups = map(object({
        description                    = string
        management_account_permissions = optional(set(string), [])
      }))

      users = optional(map(object({
        full_name = string
        email     = string
        groups    = set(string)
      })), {})
    }))

    backup = object({
      disabled = optional(bool, false)


    })

    # AWS Security Hub
    # Amazon GuardDuty
    # AWS Config
    # Amazon Macie
  })

  validation {
    error_message = "The var.config.enabled_regions contains one or more malformed region names."
    condition = alltrue([for region in var.config.enabled_regions :
    length(regexall("^(af|ap|ca|eu|me|sa|us)-(((north|south)?(east|west))|(north|south|central))-\\d$", region)) > 0])
  }

  validation {
    error_message = "At least one and no more then five break glass account is required. Recommended amount is between two and four depending on your organization size."
    condition     = 1 <= length(var.config.break_glass_accounts) && length(var.config.break_glass_accounts) <= 5
  }

  validation {
    error_message = "Invalid unit key. Allowed values includs [security infrastructure workloads sandbox individual transitional deployments exceptions policy_staging]."
    condition     = alltrue([for unit in keys(var.config.units) : contains(["security", "infrastructure", "workloads", "sandbox", "individual", "transitional", "deployments", "exceptions", "policy_staging"], unit)])
  }

  # validation {
  #   error_message = "Invalid service reference in units.enabled_services."
  #   condition = regex
  # }

  # validation {
  #   error_message = "Invalid scp reference in units scp."
  #   condition = contains
  # }

  # validation {
  #   error_message = ""
  #   condition = 
  # }
  # validation {
  #   error_message = ""
  #   condition = 
  # }
}