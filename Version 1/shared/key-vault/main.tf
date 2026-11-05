# From operate-iac: shared/security_key_vault_shared.tf
# Workload vaults (app, prizm, seq, sql) live with their workload's service, not here.

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-shared"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Security" })

}

# Upstream (by name): shared/networking private_endpoints subnet, allowed through the firewall.
data "azurerm_subnet" "private_endpoints" {
  name                 = "snet-operate-shared-private-endpoints-${local.g.suffix}"
  virtual_network_name = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name  = "rg-operate-shared-networking-${local.g.suffix}"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "key_vault" {
  name     = "rg-${local.naming}-keyvault-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_key_vault" "shared" {
  name                       = "kv-opr-shd-${local.g.env}-${local.g.location_shorthand}"
  location                   = azurerm_resource_group.key_vault.location
  resource_group_name        = azurerm_resource_group.key_vault.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  tags                       = local.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ips
    virtual_network_subnet_ids = [data.azurerm_subnet.private_endpoints.id]
  }
}
