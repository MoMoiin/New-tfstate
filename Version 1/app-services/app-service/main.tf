# From operate-iac: app-services/app_service.tf, managed_identity.tf, resource_group.tf
# The app itself is deployed by a separate pipeline (see operate-iac app-services/DEPLOY.md).

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-appsvc-${var.app_name}"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "AppService" })

}

# Upstream (by name): app-services/networking VNet integration subnet.
data "azurerm_subnet" "integration" {
  name                 = "snet-operate-appsvc-integration-${local.g.suffix}"
  virtual_network_name = "vnet-operate-appsvc-${local.g.suffix}"
  resource_group_name  = "rg-operate-appsvc-networking-${local.g.suffix}"
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_user_assigned_identity" "app" {
  name                = "mi-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  tags                = local.tags
}

resource "azurerm_service_plan" "app" {
  name                = "asp-${local.naming}-${local.g.suffix}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  os_type             = "Windows"
  sku_name            = var.sku_name
  tags                = local.tags
}

resource "azurerm_windows_web_app" "app" {
  name                      = "app-${local.naming}-${local.g.suffix}"
  location                  = azurerm_resource_group.app.location
  resource_group_name       = azurerm_resource_group.app.name
  service_plan_id           = azurerm_service_plan.app.id
  virtual_network_subnet_id = data.azurerm_subnet.integration.id
  https_only                = true
  tags                      = local.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  site_config {
    vnet_route_all_enabled = true
  }
}
