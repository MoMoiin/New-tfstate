# From operate-iac: hub/dns_private_zones.tf, hub/dns_operate_internal.tf

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-hub"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "DNS" })

  zones = merge(var.private_dns_zones, { operate = local.g.operate_dns_zone })
}

# Upstream (by name): hub/networking VNet - every zone is linked to it.
data "azurerm_virtual_network" "hub" {
  name                = "vnet-operate-hub-${local.g.suffix}"
  resource_group_name = "rg-operate-hub-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "dns" {
  name     = "rg-${local.naming}-dns-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.zones

  name                = each.value
  resource_group_name = azurerm_resource_group.dns.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = local.zones

  name                  = "link-hub-${each.key}"
  resource_group_name   = azurerm_resource_group.dns.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = data.azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = local.tags
}
