# global + environments come from global/global.tfvars; environment picks one of them -
# it is the env/<environment>.tfvars file name, passed by scripts/terraform.sh. Combined in
# main.tf as local.g.
# These three declarations are the schema of global.tfvars - keep them identical in every service.
variable "global" {
  description = "Platform-wide values (global/global.tfvars)."
  type = object({
    product            = string
    location           = string
    location_shorthand = string
    public_dns_zone    = string
    operate_dns_zone   = string
    domain_name        = string
    domain_user        = string
    public_dns = object({
      subscription_id = string
      resource_group  = string
    })
    base_tags = map(string)
  })
}

variable "environments" {
  description = "Every environment, keyed by name (global/global.tfvars)."
  type = map(object({
    env             = string
    subscription_id = string
    suffix          = string
    second_octet    = number
    ad_private_ip   = string
    tags            = map(string)
  }))
}

variable "environment" {
  description = "Which entry of var.environments this run targets, e.g. prod-uks."
  type        = string

  validation {
    condition     = contains(keys(var.environments), var.environment)
    error_message = "environment must be one of the keys of environments in global/global.tfvars."
  }
}

variable "sql_admin_group" {
  description = "Entra group that administers the SQL server."
  type = object({
    login     = string
    object_id = string
  })
}

variable "elastic_pool" {
  description = "Elastic pool sizing."
  type = object({
    sku_name     = string
    tier         = string
    family       = string
    capacity     = number
    max_size_gb  = number
    min_capacity = number
    max_capacity = number
  })
}
