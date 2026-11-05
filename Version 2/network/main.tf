# Hub + shared VNets in one state (was v1 hub/networking + shared/networking). Azure names are
# unchanged - every other service still looks these up by name.
# From operate-iac: shared/network_vnet.tf, network_subnet_*.tf, network_peering.tf,
# network_nat_gateway.tf, dns_private_zone_links.tf

locals {
  g    = merge(var.global, var.environments[var.environment])
  tags = merge(local.g.base_tags, local.g.tags, { service = "Networking" })

  # Shared VNet sits one octet above the hub's.
  hub_cidr    = "10.${local.g.second_octet}.0.0/20"
  shared_cidr = "10.${local.g.second_octet + 1}.0.0/20"
}

# -- Hub ------------------------------------------------------------------------

resource "azurerm_resource_group" "hub" {
  name     = "rg-operate-hub-networking-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-operate-hub-${local.g.suffix}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = [local.hub_cidr]
  tags                = local.tags
}

# One /24 per entry in var.hub_subnet_netnums (app, shared, ci_runner).
resource "azurerm_subnet" "hub" {
  for_each = var.hub_subnet_netnums

  name                 = "snet-operate-hub-${replace(each.key, "_", "-")}-${local.g.suffix}"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(local.hub_cidr, 4, each.value)]
  service_endpoints    = ["Microsoft.KeyVault"]
}

# -- Shared ---------------------------------------------------------------------
# DNS server is local.g.ad_private_ip from global.tfvars.

resource "azurerm_resource_group" "shared" {
  name     = "rg-operate-shared-networking-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "shared" {
  name                = "vnet-operate-shared-${local.g.suffix}"
  location            = azurerm_resource_group.shared.location
  resource_group_name = azurerm_resource_group.shared.name
  address_space       = [local.shared_cidr]
  dns_servers         = [local.g.ad_private_ip]
  tags                = local.tags
}

# One /24 per entry in var.shared_subnet_netnums.
resource "azurerm_subnet" "shared" {
  for_each = var.shared_subnet_netnums

  name                 = "snet-operate-shared-${replace(each.key, "_", "-")}-${local.g.suffix}"
  resource_group_name  = azurerm_resource_group.shared.name
  virtual_network_name = azurerm_virtual_network.shared.name
  address_prefixes     = [cidrsubnet(local.shared_cidr, 4, each.value)]
}

resource "azurerm_virtual_network_peering" "shared_to_hub" {
  name                      = "peer-shared-to-hub"
  resource_group_name       = azurerm_resource_group.shared.name
  virtual_network_name      = azurerm_virtual_network.shared.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
}
