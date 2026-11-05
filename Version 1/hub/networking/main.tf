locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-hub"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Networking" })

  vnet_cidr = "10.${local.g.second_octet}.0.0/20"
}

resource "azurerm_resource_group" "networking" {
  name     = "rg-${local.naming}-networking-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [local.vnet_cidr]
  tags                = local.tags
}

# One /24 per entry in var.subnet_netnums (bastion, gateway, app, shared, ci_runner).
resource "azurerm_subnet" "this" {
  for_each = var.subnet_netnums

  name                 = "snet-${local.naming}-${replace(each.key, "_", "-")}-${local.g.suffix}"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(local.vnet_cidr, 4, each.value)]
  service_endpoints    = ["Microsoft.KeyVault"]
}
