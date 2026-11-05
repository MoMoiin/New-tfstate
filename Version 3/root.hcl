# root.hcl - included by every unit (<service>/env/<environment>[/<customer>]/terragrunt.hcl).
#
# The unit's path is its address, the same rule as v2's env/<environment>.tfvars file names:
#   network/env/prod-uks            service = network,       environment = prod-uks
#   customer-data/env/prod-uks/acme service = customer-data, environment = prod-uks, customer = acme
#
# From that, this file sets everything that is the same for all units: tool versions, backend
# (state key per service/customer), provider, and the `context` input from global/global.hcl.

terraform_binary              = "terraform" # Terragrunt 1.x defaults to OpenTofu
terraform_version_constraint  = "~> 1.13"
terragrunt_version_constraint = "~> 1.2"

locals {
  root  = dirname(find_in_parent_folders("root.hcl"))
  parts = split("/", trimprefix(get_terragrunt_dir(), "${local.root}/"))

  service     = local.parts[0]
  environment = local.parts[2]
  customer    = length(local.parts) > 3 ? local.parts[3] : null

  globals = read_terragrunt_config("${local.root}/global/global.hcl").locals
  env     = local.globals.environments[local.environment]

  context = merge(
    { for k, v in local.globals.global : k => v if k != "base_tags" },
    { for k, v in local.env : k => v if k != "tags" },
    { tags = merge(local.globals.global.base_tags, local.env.tags) },
  )

  state_key = join("/", compact([local.service, local.customer, "terraform.tfstate"]))
}

# State storage is created per subscription by initialize-subscription.ps1.
remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    subscription_id      = local.env.subscription_id
    resource_group_name  = "rg-operate-tfstate-${local.env.suffix}"
    storage_account_name = "stoprtfstate${local.env.env}${local.globals.global.location_shorthand}001"
    container_name       = "tfstate"
    key                  = local.state_key
    use_azuread_auth     = true
  }
}

# One provider definition for every unit - per-unit copies are how provider settings drift.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azurerm" {
      subscription_id                 = "${local.env.subscription_id}"
      resource_provider_registrations = "none"
      storage_use_azuread             = true

      features {
        key_vault {
          purge_soft_delete_on_destroy = false
        }
        resource_group {
          # Customer units are torn down whole by the customer destroy pipeline.
          prevent_deletion_if_contains_resources = ${local.customer == null}
        }
      }
    }
  EOF
}

inputs = merge(
  { context = local.context },
  local.customer == null ? {} : { customer = local.customer },
)
