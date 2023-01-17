locals {
  organization_role_name = "OrganizationAccountAccessRole"
  super_admin_role       = "OrgAdministrator"
  enabled_regions        = coalescelist(tolist(var.config.enabled_regions), [local.region_name])

  unit_tree = { for name, unit in merge(var.config.units, {
    suspended = try(var.config.units["suspended"], {
      children          = {}
      sso               = {}
      scp               = ["suspended"]
      approved_services = []
      accounts          = {}
    })

    security = merge(try(var.config.units["security"], {}), {
      children = try(var.config.units["security"].children, {})
      sso      = try(var.config.units["security"].sso, {})
      scp = setunion(try(var.config.units["security"].scp, []), [
        # "security",
      ])
      approved_services = []
      accounts = merge(try(var.config.units["security"].accounts, {}), {
        "Log archive" = {
          email = try(var.config.units["security"].accounts["Log archive"].email, format(local.email_template, "log_archive"))
          tags  = local.default_tags
          scp   = []
          sso   = {}
        }
        "Security tooling" = {
          email = try(var.config.units["security"].accounts["Security tooling"].email, format(local.email_template, "security_tooling"))
          tags  = local.default_tags
          scp   = []
          sso   = {}
        }
      })
    })

    infrastructure = merge(try(var.config.units["infrastructure"], {}), {
      children          = try(var.config.units["infrastructure"].children, {})
      sso               = try(var.config.units["infrastructure"].sso, {})
      scp               = setunion(try(var.config.units["infrastructure"].scp, []), [])
      approved_services = []
      accounts = merge(try(var.config.units["infrastructure"].accounts, {}), {
        "Backup" = {
          email = try(var.config.units["infrastructure"].accounts["Backup"].email, format(local.email_template, "backup"))
          tags  = local.default_tags
          scp   = []
          sso   = {}
        }
        "Network" = {
          email = try(var.config.units["infrastructure"].accounts["Network"].email, format(local.email_template, "network"))
          tags  = local.default_tags
          scp   = []
          sso   = {}
        }
      })
    })
  }) : name => unit }

  accounts = { for entry in setunion(
    // Parent level accounts
    flatten([
      for parent_unit_name, parent_unit in local.unit_tree : [
        for name, account in parent_unit.accounts : merge(account, {
          key             = "${parent_unit_name}/${name}"
          unit_name       = parent_unit_name
          name            = name
          parent_unit_sso = parent_unit.sso
          child_unit_sso  = {}
        })
    ]]),
    // Child Level accounts
    flatten([
      for parent_unit_name, parent_unit in local.unit_tree : [
        for child_unit_name, child_unit in parent_unit.children : [
          for name, account in child_unit.accounts : merge(account, {
            key             = "${parent_unit_name}/${child_unit_name}/${name}"
            unit_name       = "${parent_unit_name}/${child_unit_name}"
            name            = name
            parent_unit_sso = parent_unit.sso
            child_unit_sso  = child_unit.sso
          })
    ]]])
    ) :
    // Account hiearachy w. inherited sso
    entry.key => merge(entry, {
      all_sso = { for group in setunion(
        keys(entry.parent_unit_sso),
        keys(entry.child_unit_sso),
        keys(entry.sso)
        ) : group => setunion(
        try(entry.parent_unit_sso[group], []),
        try(entry.child_unit_sso[group], []),
        try(entry.sso[group], []),
      ) }
  }) }
}
