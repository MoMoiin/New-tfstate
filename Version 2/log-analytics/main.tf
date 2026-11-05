# From operate-iac: hub/monitoring_log_analytics.tf

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-hub-monitoring"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Monitoring" })
}

resource "azurerm_resource_group" "monitoring" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "hub" {
  name                = "log-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = local.tags
}
