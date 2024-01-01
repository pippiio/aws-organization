locals {
  organization_role_name         = "OrganizationAccountAccessRole"
  organization_role_arn_template = "arn:aws:iam::%s:role/${local.organization_role_name}"
  super_admin_role               = "Administrator"
  enabled_regions                = coalescelist(tolist(var.config.enabled_regions), [local.region_name])

  unit_tree = { for name, unit in merge(var.config.units, {
    security = merge(try(var.config.units["security"], {}), {
      children = try(var.config.units["security"].children, {})
      group    = try(var.config.units["security"].group, {})
      scp = setunion(try(var.config.units["security"].scp, []), [
        "security",
      ])
      approved_services = []
      accounts = merge(try(var.config.units["security"].accounts, {}), {
        "Log archive" = {
          email           = try(var.config.units["security"].accounts["Log archive"].email, format(local.email_template, "log_archive"))
          tags            = local.default_tags
          scp             = []
          group           = {}
          user            = {}
          create_iam_user = false
        }
        "Security tooling" = {
          email           = try(var.config.units["security"].accounts["Security tooling"].email, format(local.email_template, "security_tooling"))
          tags            = local.default_tags
          scp             = []
          group           = {}
          user            = {}
          create_iam_user = false
        }
      })
    })

    infrastructure = merge(try(var.config.units["infrastructure"], {}), {
      children          = try(var.config.units["infrastructure"].children, {})
      group             = try(var.config.units["infrastructure"].group, {})
      scp               = setunion(try(var.config.units["infrastructure"].scp, []), [])
      approved_services = []
      accounts = merge(try(var.config.units["infrastructure"].accounts, {}), {
        "Backup" = {
          email           = try(var.config.units["infrastructure"].accounts["Backup"].email, format(local.email_template, "backup"))
          tags            = local.default_tags
          scp             = []
          group           = {}
          user            = {}
          create_iam_user = false
        }
        "Network" = {
          email           = try(var.config.units["infrastructure"].accounts["Network"].email, format(local.email_template, "network"))
          tags            = local.default_tags
          scp             = ["network"]
          group           = {}
          user            = {}
          create_iam_user = false
        }
      })
    })

    "policy staging" = merge(try(var.config.units["policy staging"], {}), {
      children          = try(var.config.units["policy staging"].children, {})
      group             = try(var.config.units["policy staging"].group, {})
      scp               = setunion(try(var.config.units["policy staging"].scp, []), [])
      approved_services = []
      accounts = merge(try(var.config.units["policy staging"].accounts, {}), {
        "Policy Stage" = {
          email           = try(var.config.units["policy staging"].accounts["Policy Stage"].email, format(local.email_template, "policy"))
          tags            = local.default_tags
          scp             = []
          group           = {}
          user            = {}
          create_iam_user = false
        }
      })
    })

    exceptions = try(var.config.units["exceptions"], {
      children          = {}
      group             = {}
      scp               = []
      approved_services = []
      accounts          = {}
    })

    suspended = try(var.config.units["suspended"], {
      children          = {}
      group             = {}
      scp               = ["suspended"]
      approved_services = []
      accounts          = {}
    })
  }) : name => unit }

  accounts = { for entry in setunion(
    // Parent level accounts
    flatten([
      for parent_unit_name, parent_unit in local.unit_tree : [
        for name, account in parent_unit.accounts : merge(account, {
          key               = "${parent_unit_name}/${name}"
          unit_name         = parent_unit_name
          name              = name
          parent_unit_group = parent_unit.group
          child_unit_group  = {}
        })
    ]]),
    // Child Level accounts
    flatten([
      for parent_unit_name, parent_unit in local.unit_tree : [
        for child_unit_name, child_unit in parent_unit.children : [
          for name, account in child_unit.accounts : merge(account, {
            key               = "${parent_unit_name}/${child_unit_name}/${name}"
            unit_name         = "${parent_unit_name}/${child_unit_name}"
            name              = name
            parent_unit_group = parent_unit.group
            child_unit_group  = child_unit.group
          })
    ]]])
    ) :
    // Account hiearachy w. inherited sso
    entry.key => merge(entry, {
      all_group = { for group in setunion(
        keys(entry.parent_unit_group),
        keys(entry.child_unit_group),
        keys(entry.group)
        ) : group => setunion(
        try(entry.parent_unit_group[group], []),
        try(entry.child_unit_group[group], []),
        try(entry.group[group], []),
      ) }
  }) }
}
