locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-hub"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Security" })
}

# Upstream (by name): hub/networking shared subnet, allowed through the KV firewall.
data "azurerm_subnet" "hub_shared" {
  name                 = "snet-operate-hub-shared-${local.g.suffix}"
  virtual_network_name = "vnet-operate-hub-${local.g.suffix}"
  resource_group_name  = "rg-operate-hub-networking-${local.g.suffix}"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "key_vault" {
  name     = "rg-${local.naming}-keyvault-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_key_vault" "hub" {
  name                       = "kv-opr-hub-${local.g.env}-${local.g.location_shorthand}"
  location                   = azurerm_resource_group.key_vault.location
  resource_group_name        = azurerm_resource_group.key_vault.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = var.soft_delete_retention_days
  tags                       = local.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ips
    virtual_network_subnet_ids = [data.azurerm_subnet.hub_shared.id]
  }
}
