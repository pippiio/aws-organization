variable "config" {
  type = object({
    organization_kms_arn   = string
    organization_role_name = string
    enabled_regions        = set(string)
  })
}
