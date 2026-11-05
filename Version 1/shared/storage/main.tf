# From operate-iac: shared/storage_images.tf (installer payloads pulled by VM bootstrap).

locals {
  g      = merge(var.global, var.environments[var.environment])
  naming = "operate-shared-storage"
  tags   = merge(local.g.base_tags, local.g.tags, { service = "Storage" })
}

resource "azurerm_resource_group" "storage" {
  name     = "rg-${local.naming}-${local.g.suffix}"
  location = local.g.location
  tags     = local.tags
}

resource "azurerm_storage_account" "images" {
  name                            = "stoprshdimg${local.g.env}${local.g.location_shorthand}01"
  location                        = azurerm_resource_group.storage.location
  resource_group_name             = azurerm_resource_group.storage.name
  account_tier                    = "Standard"
  account_replication_type        = var.replication_type
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  tags                            = local.tags
}

resource "azurerm_storage_container" "images" {
  name                  = "images"
  storage_account_id    = azurerm_storage_account.images.id
  container_access_type = "private"
}
