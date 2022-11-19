locals {
  organization_role_name = "OrganizationAccountAccessRole"
  super_admin_role       = "OrgAdministrator"
  enabled_regions        = coalescelist(tolist(var.config.enabled_regions), [local.region_name])
}
