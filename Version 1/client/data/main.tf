# From operate-iac: client/database_sql.tf, storage_account.tf, key_vault.tf, client_secrets.tf
# The customer's stateful resources - kept apart from client/app so VMs can be rebuilt
# without touching data.

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-${var.customer}-data"
  tags   = merge(local.g.base_tags, local.g.tags, { customer = var.customer, service = "Data" })

}

# Upstream (by name): shared/sql server + elastic pool, client/networking app subnet.
data "azurerm_mssql_server" "shared" {
  name                = "sql-operate-shared-sql-${local.g.suffix}"
  resource_group_name = "rg-operate-shared-sql-${local.g.suffix}"
}

data "azurerm_mssql_elasticpool" "shared" {
  name                = "sqlep-operate-shared-sql-${local.g.suffix}"
  server_name         = data.azurerm_mssql_server.shared.name
  resource_group_name = data.azurerm_mssql_server.shared.resource_group_name
}

data "azurerm_subnet" "app" {
  name                 = "snet-operate-${var.customer}-app-${local.g.suffix}"
  virtual_network_name = "vnet-operate-${var.customer}-${local.g.suffix}"
  resource_group_name  = "rg-operate-${var.customer}-networking-${local.g.suffix}"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "data" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_mssql_database" "app" {
  name            = "sqldb-${var.customer}"
  server_id       = data.azurerm_mssql_server.shared.id
  elastic_pool_id = data.azurerm_mssql_elasticpool.shared.id
  max_size_gb     = var.database_max_size_gb
  tags            = local.tags
}

resource "azurerm_storage_account" "app" {
  name                            = "stopr${replace(var.customer, "-", "")}${local.g.env}${local.g.location_shorthand}"
  location                        = azurerm_resource_group.data.location
  resource_group_name             = azurerm_resource_group.data.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  network_rules {
    default_action             = "Deny"
    ip_rules                   = var.allowed_ips
    virtual_network_subnet_ids = [data.azurerm_subnet.app.id]
  }
}

resource "azurerm_key_vault" "app" {
  name                       = "kv-opr-${var.customer}-${local.g.env}"
  location                   = azurerm_resource_group.data.location
  resource_group_name        = azurerm_resource_group.data.name
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
    virtual_network_subnet_ids = [data.azurerm_subnet.app.id]
  }
}
