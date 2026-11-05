# ONE-OFF: adopts the existing v1 hub/key-vault + shared/key-vault resources into this service's
# new, empty state. Imports of resources already in this state are no-ops, so re-runs are safe.
#
# Delete this file once dev-uks, uat-uks and prod-uks have all been applied, then delete the
# old hub/key-vault / shared/key-vault state blobs (never destroy them - purge protection
# would lock the vault names for the retention period).

locals {
  hub_kv_rg_id    = "/subscriptions/${local.g.subscription_id}/resourceGroups/rg-operate-hub-keyvault-${local.g.suffix}"
  shared_kv_rg_id = "/subscriptions/${local.g.subscription_id}/resourceGroups/rg-operate-shared-keyvault-${local.g.suffix}"
}

import {
  to = azurerm_resource_group.hub
  id = local.hub_kv_rg_id
}

import {
  to = azurerm_key_vault.hub
  id = "${local.hub_kv_rg_id}/providers/Microsoft.KeyVault/vaults/kv-opr-hub-${local.g.env}-${local.g.location_shorthand}"
}

import {
  to = azurerm_resource_group.shared
  id = local.shared_kv_rg_id
}

import {
  to = azurerm_key_vault.shared
  id = "${local.shared_kv_rg_id}/providers/Microsoft.KeyVault/vaults/kv-opr-shd-${local.g.env}-${local.g.location_shorthand}"
}
