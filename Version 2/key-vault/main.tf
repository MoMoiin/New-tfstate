# Hub + shared platform Key Vaults in one state (was v1 hub/key-vault + shared/key-vault). Azure
# names are unchanged.
# From operate-iac: shared/security_key_vault_shared.tf
# Workload vaults (app, prizm, seq, sql) live with their workload's service, not here.

locals {
  g    = merge(var.global, var.environments[var.environment])
  tags = merge(local.g.base_tags, local.g.tags, { service = "Security" })
}

# Upstream (by name): network subnets allowed through each vault's firewall -
# hub `shared` for the hub vault, shared `private_endpoints` for the shared vault.
data "azurerm_subnet" "hub_shared" {
  name                 = "snet-operate-hub-shared-${local.g.suffix}"
  virtual_network_name = "vnet-operate-hub-${local.g.suffix}"
  resource_group_name  = "rg-operate-hub-networking-${local.g.suffix}"
}

data "azurerm_subnet" "private_endpoints" {
  name                 = "snet-operate-shared-private-endpoints-${local.g.suffix}"
  virtual_network_name = "vnet-operate-shared-${local.g.suffix}"
  resource_group_name  = "rg-operate-shared-networking-${local.g.suffix}"
}

data "azurerm_client_config" "current" {}

# -- Hub ------------------------------------------------------------------------

resource "azurerm_resource_group" "hub" {
  name     = "rg-operate-hub-keyvault-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_key_vault" "hub" {
  name                       = "kv-opr-hub-${local.g.env}-${local.g.location_shorthand}"
  location                   = azurerm_resource_group.hub.location
  resource_group_name        = azurerm_resource_group.hub.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = var.hub_soft_delete_retention_days
  tags                       = local.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = var.allowed_ips
    virtual_network_subnet_ids = [data.azurerm_subnet.hub_shared.id]
  }
}

# -- Shared ---------------------------------------------------------------------

resource "azurerm_resource_group" "shared" {
  name     = "rg-operate-shared-keyvault-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_key_vault" "shared" {
  name                       = "kv-opr-shd-${local.g.env}-${local.g.location_shorthand}"
  location                   = azurerm_resource_group.shared.location
  resource_group_name        = azurerm_resource_group.shared.name
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
