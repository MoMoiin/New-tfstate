# From operate-iac: client/vm_app.tf, vm_extension.tf, passwords.tf, managed_identity.tf,
# datadog.tf, application_gateway.tf
# Real contents: var.vm_instance_count Windows VMs from var.image_id, set-admin-password Run
# Command, CSE chain (join-domain, provision), Datadog agent. AG host wiring stays in the
# pipeline (scripts/lib/AgWiring.ps1) against shared/app-gateway's outputs.

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-${var.customer}-app"
  tags   = merge(local.g.base_tags, local.g.tags, { customer = var.customer, service = "App" })

  nodes = { for i in range(var.vm_instance_count) : format("%02d", i + 1) => i }
}

# Upstream (by name): client/networking app subnet for this customer.
data "azurerm_subnet" "app" {
  name                 = "snet-operate-${var.customer}-app-${local.g.suffix}"
  virtual_network_name = "vnet-operate-${var.customer}-${local.g.suffix}"
  resource_group_name  = "rg-operate-${var.customer}-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "mi-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = local.tags
}

resource "azurerm_network_interface" "app" {
  for_each = local.nodes

  name                = "nic-${local.naming}-${local.g.env}-${local.g.location_shorthand}-${each.key}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.app.id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(data.azurerm_subnet.app.address_prefixes[0], 4 + each.value)
  }
}
