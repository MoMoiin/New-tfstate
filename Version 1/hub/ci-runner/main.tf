# From operate-iac: hub/compute_ci_runner.tf
# Real contents: Ubuntu VM (var.vm_size) with the UAMI below. Agent registration stays out
# of apply - scripts/bootstrap/register-ci-runner-agent.ps1.

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-hub-ci-runner"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "CI" })

}

# Upstream (by name): hub/networking ci_runner subnet.
data "azurerm_subnet" "hub_ci_runner" {
  name                 = "snet-operate-hub-ci-runner-${local.g.suffix}"
  virtual_network_name = "vnet-operate-hub-${local.g.suffix}"
  resource_group_name  = "rg-operate-hub-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "ci_runner" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "ci_runner" {
  name                = "mi-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.ci_runner.location
  resource_group_name = azurerm_resource_group.ci_runner.name
  tags                = local.tags
}

resource "azurerm_network_interface" "ci_runner" {
  name                = "nic-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.ci_runner.location
  resource_group_name = azurerm_resource_group.ci_runner.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.hub_ci_runner.id
    private_ip_address_allocation = "Dynamic"
  }
}
