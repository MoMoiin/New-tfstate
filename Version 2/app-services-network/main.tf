# From operate-iac: app-services/virtual_network.tf, subnet_integration.tf, vnet_peering.tf,
# dns_private_zone_links.tf

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-appsvc"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Networking" })

}

# Upstream (by name): network hub VNet, the peering target. DNS server is
# local.g.ad_private_ip from global.tfvars.
data "azurerm_virtual_network" "hub" {
  name                = "vnet-operate-hub-${local.g.suffix}"
  resource_group_name = "rg-operate-hub-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "networking" {
  name     = "rg-${local.naming}-networking-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "appsvc" {
  name                = "vnet-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [var.address_space]
  dns_servers         = [local.g.ad_private_ip]
  tags                = local.tags
}

resource "azurerm_subnet" "integration" {
  name                 = "snet-${local.naming}-integration-${local.g.suffix}"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.appsvc.name
  address_prefixes     = [cidrsubnet(var.address_space, 2, 0)]

  delegation {
    name = "app-service"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_virtual_network_peering" "appsvc_to_hub" {
  name                      = "peer-appsvc-to-hub"
  resource_group_name       = azurerm_resource_group.networking.name
  virtual_network_name      = azurerm_virtual_network.appsvc.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}
