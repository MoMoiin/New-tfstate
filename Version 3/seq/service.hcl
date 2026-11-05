# seq - shared by every env/<environment>/terragrunt.hcl below.
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

# Apply order only - the code looks these services' resources up by name, it doesn't
# read their state.
# private-dns: writes its A record into the operate.internal zone.
dependencies {
  paths = [
    "${local.root}/network/env/${local.environment}",
    "${local.root}/private-dns/env/${local.environment}",
  ]
}
