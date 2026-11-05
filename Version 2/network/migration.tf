# ONE-OFF: adopts the existing v1 hub/networking + shared/networking resources into this service's
# new, empty state, so the first run plans "N to import, 0 to add" instead of recreating them.
# Imports of resources already in this state are no-ops, so re-runs are safe.
#
# Delete this file once dev-uks, uat-uks and prod-uks have all been applied - an environment
# created after that has nothing to import and would fail on it. Then delete the old
# hub/networking / shared/networking state blobs (don't destroy them - that would delete the VNets).

locals {
  hub_rg_id    = "/subscriptions/${local.g.subscription_id}/resourceGroups/rg-operate-hub-networking-${local.g.suffix}"
  shared_rg_id = "/subscriptions/${local.g.subscription_id}/resourceGroups/rg-operate-shared-networking-${local.g.suffix}"

  hub_vnet_id    = "${local.hub_rg_id}/providers/Microsoft.Network/virtualNetworks/vnet-operate-hub-${local.g.suffix}"
  shared_vnet_id = "${local.shared_rg_id}/providers/Microsoft.Network/virtualNetworks/vnet-operate-shared-${local.g.suffix}"
}

import {
  to = azurerm_resource_group.hub
  id = local.hub_rg_id
}

import {
  to = azurerm_virtual_network.hub
  id = local.hub_vnet_id
}

import {
  for_each = var.hub_subnet_netnums
  to       = azurerm_subnet.hub[each.key]
  id       = "${local.hub_vnet_id}/subnets/snet-operate-hub-${replace(each.key, "_", "-")}-${local.g.suffix}"
}

import {
  to = azurerm_resource_group.shared
  id = local.shared_rg_id
}

import {
  to = azurerm_virtual_network.shared
  id = local.shared_vnet_id
}

import {
  for_each = var.shared_subnet_netnums
  to       = azurerm_subnet.shared[each.key]
  id       = "${local.shared_vnet_id}/subnets/snet-operate-shared-${replace(each.key, "_", "-")}-${local.g.suffix}"
}

import {
  to = azurerm_virtual_network_peering.shared_to_hub
  id = "${local.shared_vnet_id}/virtualNetworkPeerings/peer-shared-to-hub"
}
