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

variable "customer" {
  description = "Customer name, e.g. acme - the env/<environment>/<customer> folder name, passed by root.hcl."
  type        = string
}

variable "address_space" {
  description = "Customer VNet /22, allocated from the slot's customer IPAM range."
  type        = string
}
