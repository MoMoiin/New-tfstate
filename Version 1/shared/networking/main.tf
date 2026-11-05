# From operate-iac: shared/network_vnet.tf, network_subnet_*.tf, network_peering.tf,
# network_nat_gateway.tf, dns_private_zone_links.tf

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-shared"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Networking" })

  # Shared VNet sits one octet above the hub's.
  vnet_cidr = "10.${local.g.second_octet + 1}.0.0/20"

}

# Upstream (by name): hub/networking VNet, the peering target. DNS server is
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

resource "azurerm_virtual_network" "shared" {
  name                = "vnet-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [local.vnet_cidr]
  dns_servers         = [local.g.ad_private_ip]
  tags                = local.tags
}

# One /24 per entry in var.subnet_netnums.
resource "azurerm_subnet" "this" {
  for_each = var.subnet_netnums

  name                 = "snet-${local.naming}-${replace(each.key, "_", "-")}-${local.g.suffix}"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [cidrsubnet(local.vnet_cidr, 4, each.value)]
}

resource "azurerm_virtual_network_peering" "shared_to_hub" {
  name                      = "peer-shared-to-hub"
  resource_group_name       = azurerm_resource_group.networking.name
  virtual_network_name      = azurerm_virtual_network.shared.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}
