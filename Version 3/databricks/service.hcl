# databricks - shared by every env/<environment>/terragrunt.hcl below.
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
