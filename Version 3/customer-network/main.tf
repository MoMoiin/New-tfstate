# From operate-iac: client/virtual_network.tf, vnet_subnet.tf, vnet_peering.tf,
# network_security_groups.tf, ip_group.tf, dns_private_zone_links.tf, dns_operate_record.tf

locals {
  g      = var.context
  naming = "operate-${var.customer}"
  tags   = merge(local.g.tags, { customer = var.customer, service = "Networking" })

  peerings = {
    hub    = data.azurerm_virtual_network.hub.id
    shared = data.azurerm_virtual_network.shared.id
  }
}

# Upstream (by name): network hub + shared VNets, the peering targets.
# DNS server is local.g.ad_private_ip from global.hcl.
data "azurerm_virtual_network" "hub" {
  name                = "vnet-operate-hub-${local.g.suffix}"
  resource_group_name = "rg-operate-hub-networking-${local.g.suffix}"
}

data "azurerm_virtual_network" "shared" {
  name                = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name = "rg-operate-shared-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "networking" {
  name     = "rg-${local.naming}-networking-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "client" {
  name                = "vnet-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [var.address_space]
  dns_servers         = [local.g.ad_private_ip]
  tags                = local.tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-${local.naming}-app-${local.g.suffix}"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.client.name
  address_prefixes     = [cidrsubnet(var.address_space, 2, 1)]
  service_endpoints    = ["Microsoft.KeyVault", "Microsoft.Storage", "Microsoft.Sql"]
}

resource "azurerm_virtual_network_peering" "client_to" {
  for_each = local.peerings

  name                      = "peer-${var.customer}-to-${each.key}"
  resource_group_name       = azurerm_resource_group.networking.name
  virtual_network_name      = azurerm_virtual_network.client.name
  remote_virtual_network_id = each.value
  allow_forwarded_traffic   = true
}
