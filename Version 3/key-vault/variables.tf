# Global + environment values, set by root.hcl from global/global.hcl (the entry of
# `environments` named by this unit's env/<environment> folder). Keep this declaration
# identical in every service.
variable "context" {
  description = "Merged global + environment values (root.hcl)."
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
    env             = string
    subscription_id = string
    suffix          = string
    second_octet    = number
    ad_private_ip   = string
    tags            = map(string)
  })
}

variable "hub_soft_delete_retention_days" {
  description = "Hub vault only - the shared vault keeps the Azure default (90). Fixed once the vault exists."
  type        = number
  default     = 90
}

variable "allowed_ips" {
  description = "Public IPs allowed through both Key Vault firewalls."
  type        = list(string)
  default     = []
}
