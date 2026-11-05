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

variable "hub_subnet_netnums" {
  description = "Hub subnet name -> which /24 of the hub /20 it takes."
  type        = map(number)
  default = {
    app       = 1
    shared    = 2
    ci_runner = 3
  }
}

variable "shared_subnet_netnums" {
  description = "Shared subnet name -> which /24 of the shared /20 it takes."
  type        = map(number)
  default = {
    app_cluster       = 2
    private_endpoints = 3
    vm                = 4
    appgw             = 5
  }
}
