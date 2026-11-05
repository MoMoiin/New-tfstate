# From operate-iac: shared/database_sql.tf, security_key_vault_sql.tf, mock_reporting_sql.tf,
# shared/modules/sql_server_pool. Customer databases are created by client/data.

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-shared-sql"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Database" })
}

resource "azurerm_resource_group" "sql" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_mssql_server" "shared" {
  name                          = "sql-${local.naming}-${local.g.suffix}"
  location                      = azurerm_resource_group.sql.location
  resource_group_name           = azurerm_resource_group.sql.name
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = local.tags

  azuread_administrator {
    login_username              = var.sql_admin_group.login
    object_id                   = var.sql_admin_group.object_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_elasticpool" "shared" {
  name                = "sqlep-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.sql.location
  resource_group_name = azurerm_resource_group.sql.name
  server_name         = azurerm_mssql_server.shared.name
  max_size_gb         = var.elastic_pool.max_size_gb
  tags                = global.global.tags

  sku {
    name     = var.elastic_pool.sku_name
    tier     = var.elastic_pool.tier
    family   = var.elastic_pool.family
    capacity = var.elastic_pool.capacity
  }

  per_database_settings {
    min_capacity = var.elastic_pool.min_capacity
    max_capacity = var.elastic_pool.max_capacity
  }
}
