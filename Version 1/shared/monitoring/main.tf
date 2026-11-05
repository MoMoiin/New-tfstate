# From operate-iac: shared/datadog.tf, monitoring_datadog_sql.tf,
# templates/datadog-sqlserver-conf.yaml.tftpl
# Real contents: Datadog SQL monitoring container (ACI) + its identity, granted on shared/sql.

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-shared-monitoring"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Monitoring" })

}

# Upstream (by name): shared/sql server, the one Datadog monitors.
data "azurerm_mssql_server" "shared" {
  name                = "sql-operate-shared-sql-${local.g.suffix}"
  resource_group_name = "rg-operate-shared-sql-${local.g.suffix}"
}

resource "azurerm_resource_group" "monitoring" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "datadog" {
  name                = "mi-${local.naming}-datadog-${local.g.suffix}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  tags                = merge(local.tags, { monitors = data.azurerm_mssql_server.shared.name, datadog-site = var.datadog_site })
}
