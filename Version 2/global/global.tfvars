# The ONE global file. Passed to every service on every run:
#   terraform plan -var-file=../global/global.tfvars -var-file=env/<environment>.tfvars
#
# The service's env/<environment>.tfvars sets `environment` (a key below), and its main.tf
# picks it out with:
#   local.g = merge(var.global, var.environments[var.environment])
#
# Schema: the `global` / `environments` variable types in any service's variables.tf.

# -- Same for every environment -------------------------------------------------
global = {
  product            = "clio-operate"
  location           = "uksouth"
  location_shorthand = "uks"
  public_dns_zone    = "sharedo.co.uk"
  operate_dns_zone   = "operate.internal"
  domain_name        = "sharedo.local"
  domain_user        = "sharedo\\sharedoAdmin"

  public_dns = {
    subscription_id = "00000000-0000-0000-0000-00000000d115"
    resource_group  = "sharedoPublicGateway"
  }

  # Merged with environments[*].tags and the service's own tags in every main.tf.
  base_tags = {
    managed-by      = "operate-iac"
    product         = "clio-operate"
    business-region = "united-kingdom"
    customer        = "shared"
    version         = "none"
  }
}

# -- One entry per environment (= one subscription) ------------------------------
# second_octet:  hub VNet 10.<n>.0.0/20, shared VNet 10.<n+1>.0.0/20.
# ad_private_ip: static IP of domain-controller (.68 in the hub app /24) - every VNet
#                in the environment uses it as its DNS server.
environments = {
  dev-uks = {
    env             = "dev"
    subscription_id = "00000000-0000-0000-0000-000000000001"
    suffix          = "dev-uks-01"
    second_octet    = 130
    ad_private_ip   = "10.130.1.68"

    tags = {
      env             = "development"
      cost-allocation = "Research and Development"
    }
  }

  uat-uks = {
    env             = "uat"
    subscription_id = "00000000-0000-0000-0000-000000000002"
    suffix          = "uat-uks-01"
    second_octet    = 120
    ad_private_ip   = "10.120.1.68"

    tags = {
      env             = "user-acceptance-testing"
      cost-allocation = "Cost of Goods Sold"
    }
  }

  prod-uks = {
    env             = "prod"
    subscription_id = "00000000-0000-0000-0000-000000000003"
    suffix          = "prod-uks-01"
    second_octet    = 100
    ad_private_ip   = "10.100.1.68"

    tags = {
      env             = "production"
      cost-allocation = "Cost of Goods Sold"
    }
  }
}
