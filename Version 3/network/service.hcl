# network - shared by every env/<environment>/terragrunt.hcl below.
# Values that differ by environment go in that terragrunt.hcl.

locals {
  root = dirname(find_in_parent_folders("root.hcl"))
  # Unit folder is env/<environment>.
  environment = basename(get_terragrunt_dir())
}

terraform {
  # This folder - the Terraform code next to service.hcl.
  source = dirname(find_in_parent_folders("service.hcl"))
}

inputs = {
  hub_subnet_netnums = {
    app       = 1
    shared    = 2
    ci_runner = 3
  }
  shared_subnet_netnums = {
    app_cluster       = 2
    private_endpoints = 3
    vm                = 4
    appgw             = 5
  }
}
